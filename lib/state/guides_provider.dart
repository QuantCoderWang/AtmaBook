import 'package:flutter/foundation.dart';

import '../core/utils/ids.dart';
import '../data/models/guide.dart';
import '../data/models/map_source.dart';
import '../data/repos/guide_repository.dart';
import '../data/seed_data.dart';

/// 攻略列表状态：仓库（JSON 落盘）驱动；所有增删改随即持久化。
/// 无仓库（单元测试 / 特殊降级）时退化为内存演示数据。
class GuidesProvider extends ChangeNotifier {
  GuidesProvider({
    GuideRepository? repository,
    List<Guide> guides = const [],
    Map<String, Uint8List> covers = const {},
  })  : repository = repository,
        _guides = [...guides],
        _coverMemory = {...covers} {
    if (repository == null && _guides.isEmpty) {
      _guides.add(SeedData.buildDemoGuide());
    }
  }

  final GuideRepository? repository;

  final List<Guide> _guides;

  /// 封面内存镜像（桌面读自 pics 文件、Web 读自偏好设置 blob），UI 统一取用
  final Map<String, Uint8List> _coverMemory;

  List<Guide> get guides => List.unmodifiable(_guides);

  Uint8List? coverPreview(String guideId) => _coverMemory[guideId];

  Guide? byId(String id) {
    for (final g in _guides) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// 创建攻略（创建向导收口）：origin 为检索结果（可选）
  Future<Guide> create({
    required String title,
    required String summary,
    required GuideRegion region,
    GeoPlaceOrigin? origin,
  }) async {
    final now = DateTime.now();
    var guide = Guide(
      id: newId('gd'),
      title: title.trim(),
      summary: summary.trim(),
      region: region,
      sourceId: MapSources.forRegion(region).id,
      createdAt: now,
      updatedAt: now,
      originName: origin?.name,
      originLat: origin?.lat,
      originLng: origin?.lng,
    );
    if (repository != null) {
      try {
        await repository!.save(guide);
      } catch (_) {
        // 落盘失败不阻塞内存态；下次改动会重试保存
      }
    }
    _guides.insert(0, guide);
    notifyListeners();
    _persistIndex();
    return guide;
  }

  /// 分享文件导入收口：新攻略落库（shared=true 入库已在重映射时定）+ 封面进内存镜像
  Future<Guide> addImported(Guide guide, {Uint8List? coverBytes}) async {
    if (repository != null) {
      try {
        await repository!.save(guide);
      } catch (_) {}
    }
    if (coverBytes != null) {
      _coverMemory[guide.id] = coverBytes;
    }
    _guides.insert(0, guide);
    notifyListeners();
    _persistIndex();
    return guide;
  }

  /// 一键清空全部攻略（设置页危险操作）：删除全部攻略及其图片目录/封面缓存，
  /// 并清空索引；重启应用后 loadAll 发现空库会自动恢复演示攻略。
  Future<void> removeAll() async {
    final ids = [for (final g in _guides) g.id];
    _guides.clear();
    _coverMemory.clear();
    notifyListeners();
    for (final id in ids) {
      if (repository != null) {
        try {
          await repository!.delete(id);
        } catch (_) {}
      }
    }
    _persistIndex();
  }

  /// 是否已导入过同指纹的分享攻略（查重）
  bool hasShareKey(String fingerprint) =>
      _guides.any((g) => g.shared && g.shareKey == fingerprint);

  /// 覆盖一篇攻略（编辑收口）
  Future<void> replace(Guide guide) async {
    final i = _guides.indexWhere((g) => g.id == guide.id);
    if (i < 0) return;
    _guides[i] = guide;
    notifyListeners();
    if (repository != null) {
      try {
        await repository!.save(guide);
      } catch (_) {}
      _persistIndex();
    }
  }

  /// 删除攻略（连文件：JSON + 对应 pics 目录 + 封面缓存）
  Future<void> remove(String id) async {
    final i = _guides.indexWhere((g) => g.id == id);
    if (i < 0) return;
    _guides.removeAt(i);
    _coverMemory.remove(id);
    notifyListeners();
    if (repository != null) {
      try {
        await repository!.delete(id);
      } catch (_) {}
      _persistIndex();
    }
  }

  /// 设置并持久化封面（null = 移除封面）
  /// - 桌面：写 `pics/<guideId>/cover.*`，Guide.coverImage 存相对路径；
  /// - Web：偏好设置 blob（≤1MB 持久），同样写入相对路径保持模型一致。
  Future<void> setCoverBytes(String guideId, Uint8List? bytes) async {
    final old = byId(guideId);
    if (old == null) return;
    if (bytes == null) {
      _coverMemory.remove(guideId);
      final rel = old.coverImage;
      await replace(old.copyWith(clearCover: true));
      if (repository != null && rel != null) {
        try {
          await repository!.deleteCoverFile(rel);
        } catch (_) {}
      }
      return;
    }
    _coverMemory[guideId] = bytes;
    var rel = old.coverImage;
    if (repository != null) {
      try {
        rel = await repository!.saveCover(guideId, bytes);
      } catch (_) {}
    }
    await replace(old.copyWith(coverImage: rel, clearCover: false));
  }

  void _persistIndex() {
    repository?.writeIndex(guides);
  }
}

/// 创建向导回传的范围来源（WGS-84）
class GeoPlaceOrigin {
  const GeoPlaceOrigin(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;
}
