import 'package:flutter_test/flutter_test.dart';

import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/map_source.dart';
import 'package:atma_book/services/cluster_service.dart';
import 'package:atma_book/services/guide_notes_service.dart';

/// 攻略笔记生成器测试（M8）：
/// 距离序 / 推荐住宿 / 无住宿数量序 / 圈内外分流 / 选去附挂 / 面积口径。
/// 全部纯本地计算，不触碰存储层。
/// 坐标约定（lat 30 度附近）：1° 经度 ≈ 96km；片区内互距 ≤ 3km（eps）。

Place _mk(String id, double lat, double lng,
        {String cat = 'scenic', bool must = true}) =>
    Place(
        id: id,
        title: id,
        categoryId: cat,
        lat: lat,
        lng: lng,
        mustVisit: must);

Future<Guide> _guideWithZones(List<Place> ms) async {
  final t = DateTime(2026);
  final base = Guide(
      id: 'g1',
      title: '测试攻略',
      summary: '',
      region: GuideRegion.china,
      sourceId: 'amap_vector',
      createdAt: t,
      updatedAt: t,
      markers: ms);
  final r = await ClusterService.buildZones(
      guide: base, epsMeters: 3000, minPts: 2);
  return base.copyWith(clusters: r.zones);
}

void main() {
  test('有住宿：片区按起点距离升序；推荐住宿=距群质心最近', () async {
    final g = await _guideWithZones([
      // 片区 A（中心≈120.025，两点互距 0.96km）
      _mk('m1', 30.00, 120.03),
      _mk('m2', 30.00, 120.02),
      // 片区 B（中心≈121.49，互距 1.93km）
      _mk('m3', 30.00, 121.48),
      _mk('m4', 30.00, 121.50),
      // 两家住宿：h1 距片区群质心（≈120.76）更近 → 推荐
      _mk('h1', 30.00, 120.60, cat: 'hotel', must: false),
      _mk('h2', 30.00, 121.00, cat: 'hotel', must: false),
    ]);
    final m = await GuideNotesService.build(g);

    expect(m.hasHotel, isTrue);
    expect(m.recommendedHotelIdx, 0, reason: 'h1 更靠近片区群质心');
    final order1 = m.orderedZones(m.hotels[0]);
    final zA = order1.firstWhere(
        (z) => z.members.any((p) => p.id == 'm1'),
        orElse: () => throw StateError('m1 不在任何片区'),
        );
    final zB = order1.firstWhere(
        (z) => z.members.any((p) => p.id == 'm3'),
        orElse: () => throw StateError('m3 不在任何片区'),
        );
    expect(order1.indexOf(zA) < order1.indexOf(zB), isTrue,
        reason: '近的片区 A 应排最前');
    final order2 = m.orderedZones(m.hotels[1]);
    expect(order2.first.members.any((p) => p.id == 'm3'), isTrue,
        reason: '换 h2 为起点后，片区 B 应排最前');
  });

  test('无住宿：片区按游览点数降序', () async {
    final g = await _guideWithZones([
      // 片区 A：2 个必去
      _mk('m1', 30.00, 120.03),
      _mk('m2', 30.00, 120.02),
      // 片区 B：3 个必去（链式聚类；点更多 → 排前）
      _mk('m3', 30.00, 121.48),
      _mk('m4', 30.00, 121.50),
      _mk('m5', 30.00, 121.52),
    ]);
    final m = await GuideNotesService.build(g);
    expect(m.hasHotel, isFalse);
    final order = m.orderedZones(null);
    expect(order.first.poiCount, 3, reason: '游览点多的片区先游');
    expect(order.first.members.any((p) => p.id == 'm3'), isTrue);
  });

  test('餐饮/购物：圈内归片区全量，圈外进其他推荐', () async {
    final g = await _guideWithZones([
      _mk('m1', 30.00, 120.03),
      _mk('m2', 30.00, 120.02),
      // 圈内（A 中心≈120.025：d1=1.45km、s1=2.4km，都 ≤3km）
      _mk('d1', 30.00, 120.04, cat: 'dining', must: false),
      _mk('s1', 30.00, 120.05, cat: 'shopping', must: false),
      // 圈外（>3km）
      _mk('d2', 30.00, 122.50, cat: 'dining', must: false),
      _mk('s2', 30.00, 122.60, cat: 'shopping', must: false),
    ]);
    final m = await GuideNotesService.build(g);
    expect(m.zones, isNotEmpty);
    final zone = m.zones.firstWhere((z) => z.members.any((p) => p.id == 'm1'));
    expect(zone.dining.map((e) => e.id), contains('d1'));
    expect(zone.shopping.map((e) => e.id), contains('s1'));
    expect(m.otherPois.map((e) => e.id), containsAll(['d2', 's2']));
    expect(m.otherPois.map((e) => e.id), isNot(contains('d1')));
    expect(m.otherPois.map((e) => e.id), isNot(contains('s1')));
  });

  test('选去景点附挂最近片区，计入游览点数', () async {
    final g = await _guideWithZones([
      _mk('m1', 30.00, 120.03),
      _mk('m2', 30.00, 120.02),
      // 选去景点（非成员），落在片区 A 中心 2.4km 内
      _mk('x1', 30.00, 120.05, must: false),
    ]);
    final m = await GuideNotesService.build(g);
    final zone = m.zones.firstWhere((z) => z.members.any((p) => p.id == 'm1'));
    expect(zone.attached.map((e) => e.id), contains('x1'));
    expect(zone.poiCount, 3);
  });

  test('片区范围标记：半径与面积口径一致（π·r²）', () async {
    final g = await _guideWithZones([
      _mk('m1', 30.00, 121.48),
      _mk('m2', 30.00, 121.50),
      _mk('m3', 30.00, 121.52),
    ]);
    final m = await GuideNotesService.build(g);
    expect(m.zones, isNotEmpty);
    final z = m.zones.first;
    expect(z.zone.radiusMeters, 3000); // buildZones 用 eps 作为半径
    expect(z.areaKm2, closeTo(28.274, 0.02)); // π·9
  });

  test('无片区（无必去点且未重算）：全部平铺进 otherPois', () async {
    final t = DateTime(2026);
    final g = Guide(
        id: 'g2',
        title: '无片区攻略',
        summary: '',
        region: GuideRegion.china,
        sourceId: 'amap_vector',
        createdAt: t,
        updatedAt: t,
        markers: [
          _mk('x1', 30.0, 120.2, must: false),
          _mk('d1', 30.0, 120.3, cat: 'dining', must: false),
          _mk('h1', 30.0, 120.4, cat: 'hotel', must: false),
        ]);
    final m = await GuideNotesService.build(g); // 不传 fallback → 不重算
    expect(m.zones, isEmpty);
    expect(m.hasHotel, isTrue);
    expect(m.hotels.first.id, 'h1');
    expect(m.otherPois.map((e) => e.id), isNot(contains('h1'))); // 住宿不重复平铺
    expect(m.otherPois.map((e) => e.id), containsAll(['x1', 'd1']));
  });
}
