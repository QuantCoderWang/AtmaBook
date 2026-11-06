import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/utils/ids.dart';
import '../data/models/guide.dart';
import 'zone_layout.dart';

/// 片区聚类（目前方案仅保留片区范围规划）：
/// - DBSCAN（eps = 片区半径，minPts = 最少点数；孤点自成簇，均参与配色）；
/// - 片区布局重叠消解走 [ZoneLayout]（主片区保持范围、次片区缩半径、保底 400m）；
/// - 片区配色：按成员数降序 HSV 色环均匀取色（hue = i*360/n）。
class ClusterService {
  /// 构建片区（纯本地计算，不联网）
  static Future<ClusterResult> buildZones({
    required Guide guide,
    required double epsMeters,
    required int minPts,
  }) async {
    final members = guide.markers.where((m) => m.mustVisit).toList();
    if (members.isEmpty) {
      return const ClusterResult(zones: []);
    }

    // DBSCAN（保序：按标记列表顺序遍历，结果稳定可复现）
    final clusters = _dbscan(members, epsMeters, minPts);
    clusters.sort((a, b) => b.length.compareTo(a.length));

    final n = math.max(1, clusters.length);
    final zones = <ClusterZone>[];
    for (var i = 0; i < clusters.length; i++) {
      final pts = clusters[i];
      final center = _centroid(pts);
      zones.add(ClusterZone(
        id: newId('zn'),
        label: pts.length >= minPts
            ? '片区 ${i + 1}'
            : '孤立 · ${pts.first.title}',
        colorValue: _zoneColor(i, n).toARGB32(),
        memberIds: [for (final p in pts) p.id],
        center: center,
        radiusMeters: epsMeters,
        isolated: pts.length < minPts,
      ));
    }

    // 重叠消解
    final laid = ZoneLayout.resolve(zones);

    if (_mapEquivalent(laid, zones)) {
      // 无需修正时直接返回原件（保指针/原有引用）
      return ClusterResult(zones: zones);
    }
    return ClusterResult(zones: laid);
  }

  /// DBSCAN 主体。
  /// 核心点邻居 ≥ minPts 才扩张；边界点并入；噪声（孤立点）单列成簇。
  static List<List<Place>> _dbscan(
      List<Place> places, double eps, int minPts) {
    final clusters = <List<Place>>[];
    final visited = <int>{};
    final assigned = <int>{};

    for (var i = 0; i < places.length; i++) {
      if (visited.contains(i)) continue;
      visited.add(i);
      final neighbors = _neighbors(i, places, eps);
      // minPts：含自身（「最少 2 点成簇」= 一对近邻即可成簇）
      if (neighbors.length + 1 < minPts) continue; // 孤立点，最后单列
      final cluster = <Place>[places[i]];
      assigned.add(i);
      var queue = neighbors.toList();
      while (queue.isNotEmpty) {
        final j = queue.removeLast();
        if (!visited.contains(j)) {
          visited.add(j);
          final n2 = _neighbors(j, places, eps);
          if (n2.length + 1 >= minPts) queue.addAll(n2);
        }
        if (!assigned.contains(j)) {
          assigned.add(j);
          cluster.add(places[j]);
        }
      }
      clusters.add(cluster);
    }
    // 孤立点（未归入任何簇）各自单独成簇
    final orphans = [
      for (var i = 0; i < places.length; i++)
        if (!assigned.contains(i)) places[i]
    ];
    for (final o in orphans) {
      clusters.add([o]);
    }
    return clusters;
  }

  static List<int> _neighbors(int i, List<Place> ps, double eps) {
    final a = ps[i];
    final out = <int>[];
    for (var j = 0; j < ps.length; j++) {
      if (j == i) continue;
      if (haversineMeters(LatLng(a.lat, a.lng), LatLng(ps[j].lat, ps[j].lng)) <=
          eps) {
        out.add(j);
      }
    }
    return out;
  }

  static List<double> _centroidPt(List<Place> ps) {
    var lat = 0.0, lng = 0.0;
    for (final p in ps) {
      lat += p.lat;
      lng += p.lng;
    }
    return [lat / ps.length, lng / ps.length];
  }

  static LatLng _centroid(List<Place> ps) {
    final c = _centroidPt(ps);
    return LatLng(c[0], c[1]);
  }

  static Color _zoneColor(int i, int n) {
    final hue = (i * 360.0 / n) % 360;
    return HSVColor.fromAHSV(1.0, hue, 0.62, 0.92).toColor();
  }

  /// 修正轮前后是否等价（无重叠 → 直接复用原始 zones，避免不必要的新对象/重绘）
  static bool _mapEquivalent(List<ClusterZone> laid, List<ClusterZone> raw) {
    if (laid.length != raw.length) return false;
    for (var i = 0; i < laid.length; i++) {
      if (laid[i].radiusMeters != raw[i].radiusMeters) return false;
    }
    return true;
  }
}

/// 聚类结果：片区列表
class ClusterResult {
  const ClusterResult({required this.zones});

  final List<ClusterZone> zones;
}
