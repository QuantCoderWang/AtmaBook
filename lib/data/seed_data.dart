import 'package:latlong2/latlong.dart';

import 'models/guide.dart';
import 'models/map_source.dart';
import '../services/zone_layout.dart';

/// 记录演示攻略数据
class SeedData {
  /// 演示攻略：杭州两日游（假数据）
  static Guide buildDemoGuide() {
    const LatLng hefang = LatLng(30.241900, 120.166900); // 清河坊

    final places = <Place>[
      const Place(
        id: 'mk1', title: '断桥残雪', categoryId: 'scenic',
        lat: 30.259145, lng: 120.150890, mustVisit: true,
        description: '早上 8 点前人少，适合拍白堤全景；雪天限流，建议提前网上预约。',
        images: ['img1', 'img2'],
        links: [GeoLink('维基百科·断桥', 'https://zh.wikipedia.org/wiki/断桥_(杭州)')],
      ),
      const Place(
        id: 'mk2', title: '苏堤春晓', categoryId: 'scenic',
        lat: 30.242200, lng: 120.138500, mustVisit: true,
        description: '步行约 40 分钟走完全堤，南口租自行车体验更佳。',
        images: ['img3'],
      ),
      const Place(
        id: 'mk3', title: '湖滨音乐喷泉', categoryId: 'other',
        lat: 30.255900, lng: 120.161300, mustVisit: false,
        description: '19:00 / 20:00 两场，提前 30 分钟占前排。',
        links: [GeoLink('免费讲解攻略', 'https://example.com/fountain')],
      ),
      const Place(
        id: 'mk4', title: '灵隐寺', categoryId: 'scenic',
        lat: 30.241100, lng: 120.098200, mustVisit: true,
        description: '门票 75 元含飞来峰；影壁前早课 6:30 开放。',
        images: ['img4', 'img5'],
      ),
      const Place(
        id: 'mk5', title: '龙井村茶宴', categoryId: 'dining',
        lat: 30.222900, lng: 120.104000, mustVisit: false,
        description: '龙井虾仁 + 白切土鸡，人均 80；饭后可入园采茶。',
      ),
      const Place(
        id: 'mk6', title: '清河坊历史街区', categoryId: 'shopping',
        lat: 30.241900, lng: 120.166900, mustVisit: false,
        description: '胡庆余堂、丝绸与藕粉伴手礼，晚市更有烟火气。',
      ),
    ];

    final clusters = <ClusterZone>[
      // zone2 故意给出过大半径，用于演示「主片区/次片区」重叠修正规则：
      // ZoneLayout.resolve 会因湖滨片区成员更多而保存其半径，
      // 灵隐片区（次片区）半径自动缩小至两圈不再相交。
      ClusterZone(
        id: 'zone1', label: '湖滨核心片区',
        colorValue: 0xFFE53935,
        memberIds: const ['mk1', 'mk2', 'mk3'],
        center: const LatLng(30.2524, 120.1502), radiusMeters: 1800,
      ),
      ClusterZone(
        id: 'zone2', label: '灵隐茶乡片区',
        colorValue: 0xFF1E88E5,
        memberIds: const ['mk4', 'mk5'],
        center: const LatLng(30.2320, 120.1011), radiusMeters: 4200,
      ),
      // 孤立点：单独成簇
      ClusterZone(
        id: 'zone3', label: '清河坊街区（孤立点）',
        colorValue: 0xFF8E24AA,
        memberIds: const ['mk6'],
        center: hefang, radiusMeters: 600, isolated: true,
      ),
    ].toList();

    // 重叠消除：主片区保持范围，次片区缩小半径
    final resolvedClusters = ZoneLayout.resolve(clusters);

    final photoBase = DateTime(2026, 5, 1, 9);
    final photos = <PhotoItem>[
      PhotoItem(id: 'ph1', lat: 30.2512, lng: 120.1540,
          takenAt: photoBase.add(const Duration(hours: 1, minutes: 10)), gradientIndex: 0),
      PhotoItem(id: 'ph2', lat: 30.2562, lng: 120.1467,
          takenAt: photoBase.add(const Duration(hours: 2, minutes: 40)), gradientIndex: 1),
      PhotoItem(id: 'ph3', lat: 30.2400, lng: 120.1310,
          takenAt: photoBase.add(const Duration(hours: 4, minutes: 5)), gradientIndex: 2),
      PhotoItem(id: 'ph4', lat: 30.2389, lng: 120.1018,
          takenAt: photoBase.add(const Duration(hours: 7, minutes: 30)), gradientIndex: 3),
      PhotoItem(id: 'ph5', lat: 30.2271, lng: 120.1077,
          takenAt: photoBase.add(const Duration(hours: 9, minutes: 15)), gradientIndex: 4),
      PhotoItem(id: 'ph6', lat: 30.2431, lng: 120.1643,
          takenAt: photoBase.add(const Duration(hours: 11, minutes: 50)), gradientIndex: 5),
    ];

    final now = DateTime.now();
    return Guide(
      id: 'gd_demo_hangzhou',
      title: '杭州两日游',
      summary: '西湖漫步 + 灵隐茶饭，节奏宽松的老城慢玩。',
      region: GuideRegion.china,
      sourceId: MapSources.amapVector.id,
      createdAt: now, updatedAt: now,
      markers: places, photos: photos, clusters: resolvedClusters,
    );
  }

  static List<TilePack> get demoPacks {
    return [
      const TilePack(
        id: 'pack_xihu_vec', name: '西湖·市区包（矢量）',
        sourceId: 'amap_vector', bboxLabel: '西湖景区及周边',
        zoomMin: 12, zoomMax: 17, tileCount: 1204, sizeMb: 46.8,
      ),
      const TilePack(
        id: 'pack_xihu_sat', name: '西湖·景区包（卫星）',
        sourceId: 'amap_satellite', bboxLabel: '西湖景区',
        zoomMin: 13, zoomMax: 16, tileCount: 386, sizeMb: 21.5,
      ),
    ];
  }
}
