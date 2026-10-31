import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';
import '../../core/io/storage_adapter.dart';
import '../models/guide.dart';

/// 离线瓦片包仓库（读 pack 索引 + 区域命中检查；下载落盘/删除/体积统计将在后面补全）
class TileRepository {
  TileRepository(this.storage);

  final StorageAdapter storage;

  static const _tilesDir = 'tiles';

  /// 读取全部已落盘离线包（`tiles/<packId>/pack.json`）
  Future<List<TilePack>> loadPacks() async {
    final rels = await storage.listJsonFiles(_tilesDir);
    final out = <TilePack>[];
    for (final rel in rels) {
      if (!rel.endsWith('/pack.json')) continue;
      try {
        final j = jsonDecode(await storage.readText(rel));
        out.add(TilePack.fromJson(j));
      } catch (_) {}
    }
    return out;
  }

  /// 命中检查：范围中心距目标点 ≤ maxKm 即认为「该区域已有离线包」
  /// （真实瓦片边界过滤在 Provider 内做，检查阶段取宽松半径即可）
  Future<TilePack?> findNear(
    double wgsLat,
    double wgsLng, {
    String? sourceId,
    double maxKm = 80,
  }) async {
    final packs = await loadPacks();
    TilePack? best;
    double bestKm = double.infinity;
    for (final p in packs) {
      if (sourceId != null && p.sourceId != sourceId) continue;
      final cLat = p.centerLat;
      final cLng = p.centerLng;
      if (cLat == null || cLng == null) continue;
      final km =
          haversineMeters(LatLng(wgsLat, wgsLng), LatLng(cLat, cLng)) /
              1000;
      if (km <= maxKm && km < bestKm) {
        best = p;
        bestKm = km;
      }
    }
    return best;
  }

  /// 写入（覆盖）一个包的清单文件
  Future<void> savePackManifest(TilePack pack) => storage.writeText(
        '$_tilesDir/${pack.id}/pack.json',
        jsonEncode(pack.toJson()),
      );

  /// 删除整个包目录（含清单与瓦片）；不存在静默
  Future<void> deletePack(String packId) => storage.deleteDir('$_tilesDir/$packId');

  /// 实测某包目录占用的字节数（Web 下 base64 文件同样计入）
  Future<int> packSizeBytes(TilePack pack) async {
    final files =
        await storage.listFiles('$_tilesDir/${pack.id}');
    int sum = 0;
    for (final f in files) {
      if (f.endsWith('.json')) continue;
      try {
        final bytes = await storage.readBytes(f);
        sum += bytes?.length ?? 0;
      } catch (_) {}
    }
    return sum;
  }

  /// 某包本地实际落盘的瓦片数（不含清单文件）
  Future<int> packLocalTiles(TilePack pack) async {
    final files = await storage.listFiles('$_tilesDir/${pack.id}');
    return files.where((f) => !f.endsWith('.json')).length;
  }
}
