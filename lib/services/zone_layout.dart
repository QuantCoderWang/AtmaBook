import '../core/geo.dart';
import '../data/models/guide.dart';

/// 片区布局修正规则（显示层与聚类产出后同样调用）
///
/// 不允许片区重叠：
/// - 成员（必去地点）多者为「主片区」，保持原有覆盖半径；
/// - 成员少者为「次片区」，自动缩小半径至去两片区不再交叠（保底 minRadius）。
class ZoneLayout {
  static List<ClusterZone> resolve(
    List<ClusterZone> zones, {
    double minRadius = 400,
  }) {
    if (zones.length < 2) return zones;

    final n = zones.length;
    final radius = {
      for (var i = 0; i < n; i++) i: zones[i].radiusMeters,
    };

    // 主要片区排前：成员多者优先；成员相同则半径大者优先
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final bySize =
            zones[b].memberIds.length.compareTo(zones[a].memberIds.length);
        if (bySize != 0) return bySize;
        return radius[b]!.compareTo(radius[a]!);
      });

    for (var i = 0; i < order.length; i++) {
      final primary = zones[order[i]];
      for (var k = i + 1; k < order.length; k++) {
        final secondaryIdx = order[k];
        final secondary = zones[secondaryIdx];
        final gap =
            haversineMeters(primary.center, secondary.center);
        final ifOverlapped = gap < radius[order[i]]! + radius[secondaryIdx]!;
        if (ifOverlapped) {
          radius[secondaryIdx] = (gap - radius[order[i]]!)
              .clamp(minRadius, radius[secondaryIdx]!);
        }
      }
    }

    return [
      for (var i = 0; i < n; i++)
        zones[i].copyWithRadius(radius[i]!),
    ];
  }
}
