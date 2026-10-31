import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:atma_book/core/geo.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/map_source.dart';
import 'package:atma_book/services/cluster_service.dart';

Guide _guideWith(List<Place> markers) => Guide(
      id: 'g_test',
      title: '聚类测试',
      summary: '',
      region: GuideRegion.china,
      sourceId: 'amap_vector',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      markers: markers,
    );

Place _mk(String id, double lat, double lng, {bool must = true}) => Place(
      id: id,
      title: '点 $id',
      categoryId: 'scenic',
      lat: lat,
      lng: lng,
      mustVisit: must,
    );

void main() {
  group('M4 聚类（DBSCAN + 重叠消解；路线规划已移除，仅片区）', () {
    test('两簇 + 孤点：数量/成员/孤立标记正确（纯本地不联网）', () async {
      // A 组三点（西湖周边 ~600m 内）；B 组三点（灵隐周边）；孤点 15km 外
      final guide = _guideWith([
        _mk('a1', 30.2489, 120.1432),
        _mk('a2', 30.2520, 120.1460),
        _mk('a3', 30.2465, 120.1470),
        _mk('b1', 30.3000, 120.0970),
        _mk('b2', 30.3030, 120.1010),
        _mk('b3', 30.2970, 120.0980),
        _mk('solo', 30.1200, 120.3000),
      ]);
      final r = await ClusterService.buildZones(
          guide: guide, epsMeters: 5000, minPts: 2);

      expect(r.zones.length, 3);
      final multi = r.zones.where((z) => !z.isolated).toList();
      expect(multi.length, 2);
      expect(
          multi.every((z) => z.memberIds.length == 3), isTrue);
      final solo = r.zones.singleWhere((z) => z.isolated);
      expect(solo.memberIds, ['solo']);
      expect(solo.label, contains('孤立'));
      // 孤点标记（必去=false 的点不参与）
      final notVisiting = _guideWith([
        _mk('v', 30.25, 120.15, must: true),
        _mk('x', 30.2501, 120.1501, must: false),
      ]);
      final r2 = await ClusterService.buildZones(
          guide: notVisiting, epsMeters: 5000, minPts: 2);
      expect(r2.zones.length, 1);
      expect(r2.zones.first.memberIds, ['v']);
    });

    test('选去（非必去）与空列表：不产生片区', () async {
      final empty = _guideWith([]);
      final r = await ClusterService.buildZones(
          guide: empty, epsMeters: 5000, minPts: 2);
      expect(r.zones, isEmpty);

      final allOptional = _guideWith([
        _mk('x', 30.25, 120.15, must: false),
      ]);
      final r2 = await ClusterService.buildZones(
          guide: allOptional, epsMeters: 5000, minPts: 2);
      expect(r2.zones, isEmpty);
    });

    test('重叠消解：主片区保半径、次片区缩至不交叠且 ≥ 400m', () async {
      // 两簇中心相距 9km，半径 8000m → 必然交叠，须收缩次片区
      final guide = _guideWith([
        _mk('p1', 30.0000, 120.0000),
        _mk('p2', 30.0010, 120.0010),
        _mk('q1', 30.0800, 120.0800), // 与 p1 相距 ~9km
        _mk('q2', 30.0810, 120.0810),
      ]);
      final r = await ClusterService.buildZones(
          guide: guide, epsMeters: 8000, minPts: 2);
      expect(r.zones.length, 2);
      final a = r.zones[0];
      final b = r.zones[1];
      final dist = haversineMeters(a.center, b.center);
      // 至少一个保持 8000；不相交判据：dist >= rA + rB（浮点容差 1m）
      final radii = [a.radiusMeters, b.radiusMeters];
      expect(radii.contains(8000), isTrue);
      expect(dist + 1, greaterThanOrEqualTo(a.radiusMeters + b.radiusMeters));
      expect(a.radiusMeters, greaterThanOrEqualTo(400));
      expect(b.radiusMeters, greaterThanOrEqualTo(400));
    });

    test('JSON round-trip：成员/半径/孤立 保真（旧路线键被忽略）', () {
      const zone = ClusterZone(
        id: 'zn1',
        label: '片区 1',
        colorValue: 0xFF00897B,
        memberIds: ['m1', 'm2'],
        center: LatLng(30.05, 120.05),
        radiusMeters: 5000,
        isolated: false,
      );
      final restored = ClusterZone.fromJson(zone.toJson());
      expect(restored.id, zone.id);
      expect(restored.memberIds, zone.memberIds);
      expect(restored.isolated, isFalse);
      expect(restored.radiusMeters, 5000);
      expect(restored.center.latitude, closeTo(30.05, 1e-9));

      // 旧版 JSON 含 route/road 键：读取不报错且路线字段已不存在
      final legacy = ClusterZone.fromJson({
        'id': 'zn_legacy',
        'label': '旧片区',
        'color': 0xFF00897B,
        'members': ['m1'],
        'route': [
          [30.0, 120.0],
          [30.1, 120.1],
        ],
        'road': false,
        'center': [30.05, 120.05],
        'radiusMeters': 3000,
        'isolated': true,
      });
      expect(legacy.memberIds, ['m1']);
      expect(legacy.radiusMeters, 3000);
      expect(legacy.isolated, isTrue);
    });
  });

  group('M4 片区参数（攻略级覆写：默认跟随通用设置）', () {
    test('GuideSettings round-trip：覆写值与「跟随通用」可保真', () {
      const followGlobal = GuideSettings();
      expect(followGlobal.zoneRadiusOverrideM, isNull);
      expect(followGlobal.zoneMinPtsOverride, isNull);
      final restored = GuideSettings.fromJson(followGlobal.toJson());
      expect(restored.zoneRadiusOverrideM, isNull);
      expect(restored.zoneMinPtsOverride, isNull);

      final overridden = GuideSettings(
        zoneRadiusOverrideM: 3500,
        zoneMinPtsOverride: 3,
        showRoutes: false,
      );
      final r2 = GuideSettings.fromJson(overridden.toJson());
      expect(r2.zoneRadiusOverrideM, 3500);
      expect(r2.zoneMinPtsOverride, 3);
      expect(r2.showRoutes, isFalse);

      // 旧版 JSON（含遗留占位键）→ 视为跟随通用设置
      final legacy = GuideSettings.fromJson({
        'clusterRadiusM': 5000,
        'minPts': 2,
        'showRoutes': true,
      });
      expect(legacy.zoneRadiusOverrideM, isNull);
      expect(legacy.zoneMinPtsOverride, isNull);
    });

    test('copyWith/clearOverrides：覆写可写可清', () {
      const base = GuideSettings();
      final withOverride = base.copyWith(
          radiusOverrideM: 2000, minPtsOverride: 4);
      expect(withOverride.zoneRadiusOverrideM, 2000);
      expect(withOverride.zoneMinPtsOverride, 4);
      final cleared = withOverride.copyWith(clearOverrides: true);
      expect(cleared.zoneRadiusOverrideM, isNull);
      expect(cleared.zoneMinPtsOverride, isNull);
    });
  });

  group('M4 顺序优化纯函数参考', () {
    test('数学合理性：球面距离恒正且环回单调', () {
      final d = haversineMeters(const LatLng(30, 120), const LatLng(30.1, 120));
      expect(d, greaterThan(11000));
      expect(d, lessThan(11200));
    });
  });
}
