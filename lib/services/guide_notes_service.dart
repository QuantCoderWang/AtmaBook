import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/constants.dart';
import '../core/geo.dart';
import '../data/models/guide.dart';
import 'cluster_service.dart';

/// 攻略笔记·片区区块：一个片区（或孤立片区）的笔记内容。
///
/// - [members]：片区必去成员（zone.memberIds）里非住宿/餐饮/购物的地点
///   （即景点/交通/其他类，直接来自聚类，就近排序）；
/// - [attached]：片区内的选去景点（非聚类成员）按最近片区附挂，就近排序；
/// - [dining]/[shopping]：片区圈内的餐饮/购物（必去成员 + 圈内非成员，全量）。
class NotesZone {
  const NotesZone({
    required this.zone,
    required this.members,
    required this.attached,
    required this.dining,
    required this.shopping,
  });

  final ClusterZone zone;
  final List<Place> members;
  final List<Place> attached;
  final List<Place> dining;
  final List<Place> shopping;

  LatLng get center => zone.center;
  String get title => zone.label;
  bool get isIsolated => zone.isolated;

  /// 片区半径（公里）
  double get radiusKm => zone.radiusMeters / 1000;

  /// 片区覆盖面积（平方公里）＝ π·r²（片区为正圆圈层）
  double get areaKm2 => math.pi * math.pow(zone.radiusMeters / 1000, 2);

  /// 片区内游览点总数（必去成员 + 附挂选去）
  int get poiCount => members.length + attached.length;
}

/// 攻略笔记（地图信息数据生成）：打开即算、退出即弃，
/// 全部信息实时抽取自攻略 JSON 已有内容（Place/聚类结果）。
class NotesModel {
  const NotesModel({
    required this.hotels,
    required this.recommendedHotelIdx,
    required this.zones,
    required this.otherPois,
  });

  final List<Place> hotels;

  /// 推荐住宿下标：距片区群质心最近的住宿（页头 chips 默认选中并标注「推荐住宿」）；无住宿为 -1。
  final int recommendedHotelIdx;

  final List<NotesZone> zones;

  /// 归不进任何片区（圈外）的餐饮/购物/交通/其他（餐饮在前，无人选中起点时
  /// 也包括暂时无法归片的酒店外的所有平铺内容）。
  final List<Place> otherPois;

  bool get hasHotel => hotels.isNotEmpty;
  bool get recommendHotel =>
      recommendedHotelIdx >= 0 && recommendedHotelIdx < hotels.length;

  /// 片区群质心（各片区中心均值；无片区返回 null）
  LatLng? centroid() {
    if (zones.isEmpty) return null;
    var la = 0.0;
    var lo = 0.0;
    for (final z in zones) {
      la += z.center.latitude;
      lo += z.center.longitude;
    }
    return LatLng(la / zones.length, lo / zones.length);
  }

  /// 以 [startHotel] 为游览起点重排片区：
  /// - 有起点 → 起点到各片区中心距离升序（近的先游）；
  /// - 无起点 → 片区游览点数降序，并列时按片区中心到群质心距离升序。
  List<NotesZone> orderedZones(Place? startHotel) {
    if (zones.isEmpty) return const [];
    final list = [...zones];
    if (startHotel != null) {
      final s = LatLng(startHotel.lat, startHotel.lng);
      list.sort((a, b) {
        return haversineMeters(s, a.center)
            .compareTo(haversineMeters(s, b.center));
      });
      return list;
    }
    final c = centroid();
    list.sort((a, b) {
      final r = b.poiCount.compareTo(a.poiCount);
      if (r != 0) return r;
      if (c == null) return 0;
      return haversineMeters(c, a.center).compareTo(haversineMeters(c, b.center));
    });
    return list;
  }
}

/// 攻略笔记生成器（纯函数；不触发任何写盘）。
///
/// 片区取自攻略持久化的 `clusters`（随标记/参数变化自动重算）。为空但有
/// 必去点时，用 [epsFallbackM]/[minPtsFallback] 临时算一次（攻略级覆写优先，
/// 页面注入通用设置值），只在内存里，不落库。
/// 排序：有住宿按距离，无住宿按片区游览点数（见 [NotesModel.orderedZones]）。
/// 餐饮/购物落在片区圈内归该片区全量展示，同时落多圈取最近者，圈外进
/// [NotesModel.otherPois]。
/// 距离用 haversine（core/geo.dart，和聚类、就近归属是同一套算法）。
class GuideNotesService {
  static Future<NotesModel> build(
    Guide guide, {
    double? epsFallbackM,
    int minPtsFallback = 3,
  }) async {
    final byId = {for (final m in guide.markers) m.id: m};
    final hotels = [
      for (final m in guide.markers)
        if (m.categoryId == MarkerCategory.hotel.id) m,
    ];

    // 片区来源
    var zones = guide.clusters;
    if (zones.isEmpty) {
      final must = guide.markers.where((m) => m.mustVisit).toList();
      final eps =
          guide.settings.zoneRadiusOverrideM ?? epsFallbackM;
      if (must.isNotEmpty && eps != null) {
        final r = await ClusterService.buildZones(
          guide: guide,
          epsMeters: eps,
          minPts: guide.settings.zoneMinPtsOverride ?? minPtsFallback,
        );
        zones = r.zones;
      }
    }

    // 分区内容骨架（和 zones 对齐；无片区就全平铺进 otherPois）
    final sections = <NotesZone>[];
    final otherPois = <Place>[];

    if (zones.isEmpty) {
      // 无片区（无必去点且无法重算）：除住宿外全部平铺（餐饮在前由页面分流）
      for (final p in guide.markers) {
        if (p.categoryId == MarkerCategory.hotel.id) continue;
        otherPois.add(p);
      }
      return NotesModel(
        hotels: hotels,
        recommendedHotelIdx: -1,
        zones: const [],
        otherPois: otherPois,
      );
    }

    for (final z in zones) {
      final zScenics = <Place>[];
      final zDining = <Place>[];
      final zShopping = <Place>[];
      for (final id in z.memberIds) {
        final p = byId[id];
        if (p == null) continue;
        if (p.categoryId == MarkerCategory.hotel.id) {
          continue; // 必去住宿走页头住宿卡，不在片区内重复出现
        } else if (p.categoryId == MarkerCategory.dining.id) {
          zDining.add(p);
        } else if (p.categoryId == MarkerCategory.shopping.id) {
          zShopping.add(p);
        } else {
          zScenics.add(p);
        }
      }
      for (final l in [zScenics, zDining, zShopping]) {
        final c = z.center;
        l.sort((a, b) {
          final da = haversineMeters(LatLng(a.lat, a.lng), c);
          final db = haversineMeters(LatLng(b.lat, b.lng), c);
          return da.compareTo(db);
        });
      }
      sections.add(NotesZone(
        zone: z,
        members: zScenics,
        attached: [],
        dining: zDining,
        shopping: zShopping,
      ));
    }

    // 非成员标记分流
    final memberIds = <String>{for (final z in zones) ...z.memberIds};
    for (final p in guide.markers) {
      if (memberIds.contains(p.id)) continue;
      if (p.categoryId == MarkerCategory.hotel.id) continue; // 走住宿卡

      if (p.categoryId == MarkerCategory.dining.id ||
          p.categoryId == MarkerCategory.shopping.id) {
        // 圈内归片区（最近者），圈外进其他推荐
        final idx = _indexOfNearestZone(zones, p);
        if (idx != null) {
          final z = zones[idx];
          final d =
              haversineMeters(LatLng(p.lat, p.lng), z.center);
          if (d <= z.radiusMeters) {
            final list = p.categoryId == MarkerCategory.dining.id
                ? sections[idx].dining
                : sections[idx].shopping;
            list
              ..add(p)
              ..sort((a, b) =>
                  haversineMeters(LatLng(a.lat, a.lng), z.center)
                      .compareTo(
                          haversineMeters(LatLng(b.lat, b.lng), z.center)));
            continue;
          }
        }
        otherPois.add(p);
      } else if (p.categoryId == MarkerCategory.scenic.id && !p.mustVisit) {
        // 选去景点 → 附挂最近片区（无距离上限；无片区平铺）
        final idx = _indexOfNearestZone(zones, p);
        if (idx != null) {
          final z = zones[idx];
          sections[idx].attached
            ..add(p)
            ..sort((a, b) => haversineMeters(LatLng(a.lat, a.lng), z.center)
                .compareTo(haversineMeters(LatLng(b.lat, b.lng), z.center)));
        } else {
          otherPois.add(p);
        }
      } else {
        // 交通 / 其他类：进其他推荐
        otherPois.add(p);
      }
    }

    // 推荐住宿：离片区群质心最近
    var recIdx = -1;
    final c = sections.isEmpty
        ? null
        : (NotesModel(
            hotels: const [],
            recommendedHotelIdx: -1,
            zones: sections,
            otherPois: const [],
          ).centroid());
    if (hotels.isNotEmpty && c != null) {
      var best = double.infinity;
      for (var i = 0; i < hotels.length; i++) {
        final d = haversineMeters(LatLng(hotels[i].lat, hotels[i].lng), c);
        if (d < best) {
          best = d;
          recIdx = i;
        }
      }
    } else if (hotels.isNotEmpty && c == null) {
      recIdx = 0;
    }

    return NotesModel(
      hotels: hotels,
      recommendedHotelIdx: recIdx,
      zones: sections,
      otherPois: otherPois,
    );
  }

  /// 最近片区下标（并列取下标靠前者；zones 空 → null）
  static int? _indexOfNearestZone(List<ClusterZone> zones, Place p) {
    if (zones.isEmpty) return null;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < zones.length; i++) {
      final d = haversineMeters(
          LatLng(p.lat, p.lng), zones[i].center);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }
}
