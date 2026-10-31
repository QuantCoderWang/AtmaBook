import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'coord.dart';

/// 瓦片坐标（z/x/y，XYZ 规范；x/y 为该级别下行列号）
class TileCoord {
  const TileCoord(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  /// 本地文件的相对 key（去扩展名）
  String get key => '$z/$x/$y';

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'z$z/${z}_$x|$y';
}

/// WGS-84 经纬度 → Web 墨卡托平铺坐标（小数）
(double, double) _project(LatLng p, int z) {
  final n = 1 << z;
  final x = (p.longitude + 180.0) / 360.0 * n;
  final clamped = p.latitude < -85.0511 ? -85.0511 : (p.latitude > 85.0511 ? 85.0511 : p.latitude);
  final r = clamped * math.pi / 180.0;
  final y = n * (0.5 - (math.log(math.tan(math.pi / 4 + r / 2)) / (2 * math.pi)));
  return (x, y);
}

/// 框选对角两点 + zoom 区间 → 全部瓦片清单（M-05-01）。
///
/// - [gcjSource]：高德等 GCJ-02 源须先把边界点换算成 GCJ 坐标再取瓦片行列号，
///   才能保证「标记所在屏幕位置」与底图内容一致（渲染偏移统一处理）；
/// - 返回按 z 升序、x/y 行优先排序，下载时可顺序合并相邻瓦片。
List<TileCoord> enumerateTiles(
  LatLng a,
  LatLng b,
  List<int> zooms, {
  bool gcjSource = false,
}) {
  var p1 = a;
  var p2 = b;
  if (gcjSource) {
    final c1 = wgs84ToGcj02(a.latitude, a.longitude);
    final c2 = wgs84ToGcj02(b.latitude, b.longitude);
    p1 = LatLng(c1.$1, c1.$2);
    p2 = LatLng(c2.$1, c2.$2);
  }
  final minLat = math.min(p1.latitude, p2.latitude);
  final maxLat = math.max(p1.latitude, p2.latitude);
  final minLng = math.min(p1.longitude, p2.longitude);
  final maxLng = math.max(p1.longitude, p2.longitude);
  if ((maxLat - minLat) < 1e-9 || (maxLng - minLng) < 1e-9) return const [];

  final out = <TileCoord>[];
  for (final z in zooms) {
    final (x0, _) = _project(LatLng(maxLat, minLng), z);
    final (x1, _) = _project(LatLng(maxLat, maxLng), z);
    final (_, y0) = _project(LatLng(maxLat, minLng), z);
    final (_, y1) = _project(LatLng(minLat, minLng), z);
    final ix0 = x0.floor(), ix1 = x1.floor();
    final iy0 = y0.floor(), iy1 = y1.floor();
    // 越界保护（zoom 极小时 x/y 可能越出世界范围）
    final clip = 1 << z;
    for (var x = math.max(0, ix0); x <= math.min(clip - 1, ix1); x++) {
      for (var y = math.max(0, iy0); y <= math.min(clip - 1, iy1); y++) {
        out.add(TileCoord(z, x, y));
      }
    }
  }
  return out;
}

/// 预估总张数（与 [enumerateTiles] 同口径）
int estimateTilesPrecise(LatLng a, LatLng b, List<int> zooms,
        {bool gcjSource = false}) =>
    enumerateTiles(a, b, zooms, gcjSource: gcjSource).length;

/// 「范围过大致确认」阈值（清单 M5-01 约定 8000）
const kHugeTileCount = 8000;
