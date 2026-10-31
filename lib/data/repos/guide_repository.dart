import 'dart:convert';
import 'dart:typed_data';

import '../../core/io/storage_adapter.dart';
import '../../core/utils/json_recover.dart';
import '../models/guide.dart';
import '../seed_data.dart';

/// 攻略仓库：`guides/<guideId>.json` 一篇一文件 + `guides_index.json`
/// 薄索引（首页卡片反查用，防整目录解析；加载仍以分文件为准）。
class GuideRepository {
  GuideRepository(this.storage);

  final StorageAdapter storage;

  static const _guidesDir = 'guides';
  static const _indexFile = 'guides_index.json';

  /// 启动加载全部攻略；目录为空时写入演示攻略（首次运行，可删除）。
  /// 单文件解析失败 → 自愈抢救（截取首份完整文档，原档另存 .bad 备份），
  /// 仍失败才跳过（不阻塞启动）。
  Future<List<Guide>> loadAll() async {
    final rels = await storage.listJsonFiles(_guidesDir);
    final out = <Guide>[];
    for (final rel in rels) {
      if (!rel.contains('/')) continue; // 过滤游离的坏文件
      Guide? g;
      try {
        final txt = await storage.readText(rel);
        if (txt.trim().isNotEmpty) {
          g = Guide.fromJson(jsonDecode(txt));
        }
      } catch (_) {
        g = null;
      }
      g ??= await _recover(rel);
      if (g != null) out.add(g);
    }
    if (out.isEmpty) {
      try {
        final demo = SeedData.buildDemoGuide();
        out.add(demo);
        await save(demo);
      } catch (_) {}
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  /// 损坏自愈：解析失败 → 抢救首份完整文档 → 原档另存 .bad → 重写干净档
  Future<Guide?> _recover(String rel) async {
    try {
      final txt = await storage.readText(rel);
      final fixed = extractFirstJsonDocument(txt);
      if (fixed == null) return null;
      final g = Guide.fromJson(jsonDecode(fixed));
      try {
        await storage.writeText('$rel.bad', txt);
      } catch (_) {}
      await save(g); // 经写队列原子重写干净档
      return g;
    } catch (_) {
      return null;
    }
  }

  /// 封面字节启动加载（内存镜像，UI 统一 Image.memory）
  Future<Map<String, Uint8List>> loadCovers(List<Guide> guides) async {
    final out = <String, Uint8List>{};
    for (final g in guides) {
      if (g.coverImage == null) continue;
      try {
        final b = await storage.readBytes(g.coverImage!);
        if (b != null) out[g.id] = b;
      } catch (_) {}
    }
    return out;
  }

  Future<void> save(Guide guide) =>
      storage.writeText(
        '$_guidesDir/${guide.id}.json',
        jsonEncode(guide.toJson()),
      );

  Future<void> delete(String guideId) async {
    await storage.deleteFile('$_guidesDir/$guideId.json');
    await storage.deleteDir('pics/$guideId');
    // Web 降级的封面 blob 也随相对路径删除
    await storage.deleteFile('pics/covers/$guideId.bin');
  }

  /// 依据字节推断图片扩展名（JPEG/PNG/WebP/GIF），写入 `pics/<id>/cover.*`
  Future<String> saveCover(String guideId, Uint8List bytes) async {
    String ext;
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      ext = 'jpg';
    } else if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      ext = 'png';
    } else if (bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      ext = 'webp';
    } else {
      ext = 'gif';
    }
    final rel = 'pics/$guideId/cover.$ext';
    await storage.writeBytes(rel, bytes);
    return rel;
  }

  Future<void> deleteCoverFile(String oldRel) =>
      storage.deleteFile(oldRel);

  /// 薄索引（更新时间/标题/计数），供备份与排查；失败静默（不影响主流程）
  Future<void> writeIndex(List<Guide> guides) async {
    try {
      await storage.writeText(
        _indexFile,
        jsonEncode({
          'version': 1,
          'savedAt': DateTime.now().toIso8601String(),
          'guides': [
            for (final g in guides)
              {
                'id': g.id,
                'title': g.title,
                'summary': g.summary,
                'region': g.region.name,
                'markers': g.markers.length,
                'mustVisits': g.mustVisitCount,
                'photos': g.photos.length,
                'updatedAt': g.updatedAt.toIso8601String(),
              },
          ],
        }),
      );
    } catch (_) {}
  }
}
