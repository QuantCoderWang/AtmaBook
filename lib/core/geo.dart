import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// 地理计算工具（用于下载预览估算；聚类复用）
const double earthRadius = 6371000.0;

double _rad(double deg) => deg * math.pi / 180.0;

/// 两点球面距离（米）
double haversineMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final s = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthRadius * math.asin(math.sqrt(s));
}

double _tileX(double lng, int z) =>
    ((lng + 180.0) / 360.0) * (1 << z);

double _tileY(double lat, int z) {
  final clamped = lat < -85.05 ? -85.05 : (lat > 85.05 ? 85.05 : lat);
  final r = _rad(clamped);
  return (1 << z) *
      (0.5 - (math.log(math.tan(math.pi / 4 + r / 2)) / (2 * math.pi)));
}

/// 估算矩形范围在给定 zoom 序列下的瓦片总张数
int estimateTileCount(LatLng a, LatLng b, List<int> zooms) {
  double minLat = math.min(a.latitude, b.latitude);
  double maxLat = math.max(a.latitude, b.latitude);
  double minLng = math.min(a.longitude, b.longitude);
  double maxLng = math.max(a.longitude, b.longitude);
  if ((maxLat - minLat) < 1e-6 || (maxLng - minLng) < 1e-6) return 0;

  var total = 0;
  for (final z in zooms) {
    final x0 = _tileX(minLng, z).floor();
    final x1 = _tileX(maxLng, z).floor();
    final y0 = _tileY(maxLat, z).floor();
    final y1 = _tileY(minLat, z).floor();
    total += (x1 - x0 + 1) * (y1 - y0 + 1);
  }
  return total;
}

/// 常规瓦片按单张 ~40KB 估算的粗略数据量（MB）
double estimateSizeMb(int tileCount) => tileCount * 0.04;
