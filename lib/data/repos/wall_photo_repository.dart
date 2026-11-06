import 'dart:convert';

import '../../core/io/storage_adapter.dart';
import '../../core/utils/json_recover.dart';
import '../models/wall_photo.dart';

/// 照片墙白板库数据：`data/wall_photos.json`
/// - `photos`：照片条目；
/// - `years`：每一年照片墙的结果快照（WallYearRecord）；
/// - `hidden`：在地理相册中被手动隐藏的 uid 集合（`g:<gid>:<pid>` / `w:<wid>`）。
/// 三键合并写入（更新互不覆盖）。
class WallPhotoRepository {
  static const _rel = 'data/wall_photos.json';

  WallPhotoRepository(this.storage);

  final StorageAdapter storage;

  Map<String, dynamic> _parse(String text) {
    final j = jsonDecode(text);
    return (j is Map) ? j.cast<String, dynamic>() : {};
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      return _parse(await storage.readText(_rel));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeKeys(Map<String, dynamic> patch) async {
    final j = await _readAll();
    j['v'] = 1;
    j.addAll(patch);
    try {
      await storage.writeText(
          _rel, const JsonEncoder.withIndent('  ').convert(j));
    } catch (_) {}
  }

  Future<List<WallPhoto>> load() async {
    try {
      final j = await _readAll();
      return [
        for (final raw in (j['photos'] as List? ?? const []))
          WallPhoto.fromJson(raw),
      ];
    } catch (_) {
      // 损坏自愈：抢救首份完整文档（原档另存 .bad），仍失败返回空账本
      try {
        final txt = await storage.readText(_rel);
        final fixed = extractFirstJsonDocument(txt);
        if (fixed != null) {
          final j = _parse(fixed);
          final list = [
            for (final raw in (j['photos'] as List? ?? const []))
              WallPhoto.fromJson(raw),
          ];
          await save(list);
          return list;
        }
      } catch (_) {}
      return [];
    }
  }

  Future<void> save(List<WallPhoto> photos) => _writeKeys({
        'photos': [for (final p in photos) p.toJson()],
      });

  Future<Map<int, WallYearRecord>> loadYears() async {
    try {
      final j = await _readAll();
      final ys = (j['years'] as Map? ?? {}).cast<String, dynamic>();
      return {
        for (final e in ys.entries)
          if (int.tryParse(e.key) != null)
            int.tryParse(e.key)! : WallYearRecord.fromJson(e.value),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveYears(Map<int, WallYearRecord> years) => _writeKeys({
        'years': {
          for (final e in years.entries)
            e.key.toString(): e.value.toJson(),
        },
      });

  /// 隐藏登记：在地理相册中手动隐藏的照片 uid（库清单可见、地图不上图）
  Future<Set<String>> loadHidden() async {
    try {
      final j = await _readAll();
      return {
        for (final x in (j['hidden'] as List? ?? const []))
          if (x is String) x,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveHidden(Set<String> uids) => _writeKeys({
        'hidden': uids.toList()..sort(),
      });
}
