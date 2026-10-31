import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/core/utils/wall_layout.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/map_source.dart' show GuideRegion;
import 'package:atma_book/data/models/wall_photo.dart';
import 'package:atma_book/data/repos/wall_photo_repository.dart';
import 'package:atma_book/services/wall_photo_service.dart';

import 'data_layer_test.dart' show MemoryStorage;

/// M6 v2（白板照片墙）：布局聚类 / 空槽补位 / 取样上限 / 模型 round-trip
void main() {
  Guide guide(String id, List<PhotoItem> photos) => Guide(
        id: id,
        title: '测试攻略',
        summary: '',
        region: GuideRegion.overseas,
        sourceId: 'osm',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        photos: photos,
      );

  group('白板布局 layoutWallPhotos', () {
    test('相近照片聚一团；远点另起一团；uid 全覆盖恰一次', () {
      final layout = layoutWallPhotos([
        WallPhotoPoint(
            uid: 'a1', lat: 31.2300, lng: 121.4700, takenAt: DateTime(2026, 1)),
        WallPhotoPoint(
            uid: 'a2', lat: 31.2304, lng: 121.4695, takenAt: DateTime(2026, 2)),
        WallPhotoPoint(
            uid: 'a3', lat: 31.2307, lng: 121.4700, takenAt: DateTime(2026, 3)),
        // 相距远超 150m 的另一团
        WallPhotoPoint(
            uid: 'b1', lat: 31.4000, lng: 121.6000, takenAt: DateTime(2026, 4)),
      ]);
      expect(layout.clusters.length, 2);
      expect(
        layout.clusters.firstWhere((c) => c.members.contains('a1')).members,
        containsAll(['a1', 'a2', 'a3']),
      );
      expect(
        layout.clusters.firstWhere((c) => c.members.contains('b1')).members,
        ['b1'],
      );

      final uids = layout.placements.map((p) => p.uid).toSet();
      expect(uids, {'a1', 'a2', 'a3', 'b1'});
      expect(layout.placements.length, 4);
    });

    test('无定位照片落 loose 槽（补空位）且坐标在白板内', () {
      final layout = layoutWallPhotos([
        WallPhotoPoint(uid: 'x1', takenAt: DateTime(2026, 1)),
        WallPhotoPoint(uid: 'x2', takenAt: DateTime(2026, 2)),
        WallPhotoPoint(
            uid: 'g1', lat: 31.2, lng: 121.4, takenAt: DateTime(2026, 3)),
      ]);
      final loose =
          layout.placements.where((p) => p.groupId == 'loose').toList();
      expect(loose.length, 2);
      for (final p in loose) {
        expect(p.x, inInclusiveRange(0, 1));
        expect(p.y, inInclusiveRange(0, 1));
      }
    });

    test('同一输入 + 同一 seed → 布局确定（可复现）', () {
      List<WallPhotoPoint> make() => List.generate(
            24,
            (i) => WallPhotoPoint(
              uid: 'p$i',
              lat: 31.0 + i * 0.01,
              lng: 121.0 + i * 0.01,
              takenAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
            ),
          );
      final a = layoutWallPhotos(make(), seed: 42);
      final b = layoutWallPhotos(make(), seed: 42);
      String key(WallPlacement p) => '${p.uid}@${p.x.toStringAsFixed(5)}'
          '_${p.y.toStringAsFixed(5)}_${p.angleDeg.toStringAsFixed(3)}';
      expect(a.placements.map(key).toList(), b.placements.map(key).toList());
    });

    test('空输入：无布局仍可渲染（不抛异常）', () {
      final layout = layoutWallPhotos(const [], seed: 1);
      expect(layout.placements, isEmpty);
      expect(layout.clusters, isEmpty);
    });
  });

  group('WallPhotoService.collectPoints 取样', () {
    test('合并攻略照片 + 账本；超出 cap 时挤掉最旧', () {
      final service = WallPhotoService(MemoryStorage());

      // 攻略 3 张（2026-01/02/03）+ 账本 1 张最新（2026-12）；cap=3
      // → 应保留 2026-12 / 03 / 02，挤掉最旧的 01
      final g = guide('g1', [
        PhotoItem(
            id: 'p1',
            takenAt: DateTime(2026, 1, 1),
            lat: 31,
            lng: 121,
            file: 'pics/p1.jpg'),
        PhotoItem(
            id: 'p2',
            takenAt: DateTime(2026, 2, 1),
            lat: 31,
            lng: 121,
            file: 'pics/p2.jpg'),
        PhotoItem(
            id: 'p3',
            takenAt: DateTime(2026, 3, 1),
            lat: 31,
            lng: 121,
            file: 'pics/p3.jpg'),
      ]);
      final ledger = [
        WallPhoto(
            id: 'w1', takenAt: DateTime(2026, 12, 1), file: 'pics/w1.jpg'),
      ];
      final points = service.collectPoints(guides: [g], ledger: ledger, cap: 3);
      final uids = points.map((p) => p.uid).toSet();
      expect(uids, {'g:g1:p2', 'g:g1:p3', 'w:w1'});
      expect(points.length, 3);
    });

    test('账本条目 uid 前缀 w:；攻略条目 uid 前缀 g:；uid 天然去重', () {
      final service = WallPhotoService(MemoryStorage());
      final g = guide('g1', [
        PhotoItem(
            id: 'p1', takenAt: DateTime(2026, 5), lat: 31, lng: 121),
      ]);
      final ledger = [
        WallPhoto(id: 'wA', takenAt: DateTime(2026, 6), file: 'pics/a.jpg'),
      ];
      final points = service.collectPoints(
        guides: [g, g], // 重复传入同一攻略也不应产生重复 uid
        ledger: [...ledger, ...ledger],
        cap: 10,
      );
      final uids = points.map((p) => p.uid).toSet();
      expect(uids, {'g:g1:p1', 'w:wA'});
      expect(points.length, 2);
    });

    test('cap 边界：等于上限时不截断', () {
      final service = WallPhotoService(MemoryStorage());
      final g = guide('g1', [
        PhotoItem(id: 'p1', takenAt: DateTime(2026, 1)),
        PhotoItem(id: 'p2', takenAt: DateTime(2026, 2)),
      ]);
      final points = service.collectPoints(
        guides: [g],
        ledger: [],
        cap: 2,
      );
      expect(points.length, 2);
    });
  });

  group('年墙快照 rebuildYearIndex', () {
    test('按年生成 placements/clusters 并经仓库 round-trip 持久化', () async {
      final storage = MemoryStorage();
      final service = WallPhotoService(storage);
      final g = Guide(
        id: 'gx',
        title: '测试',
        summary: '',
        region: GuideRegion.overseas,
        sourceId: 'osm',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        photos: [
          PhotoItem(
              id: 'p1',
              takenAt: DateTime(2026, 3, 1),
              lat: 31.2,
              lng: 121.4),
          PhotoItem(
              id: 'p2', takenAt: DateTime(2026, 4, 1), lat: 31.2, lng: 121.4),
        ],
      );
      final ledger = [
        WallPhoto(
            id: 'wOld',
            takenAt: DateTime(2025, 6, 1),
            lat: 31.2,
            lng: 121.4),
      ];
      // 灌入账本（save→load 保证与真实链一致）
      await WallPhotoRepository(storage).save(ledger);

      final index = await service.rebuildYearIndex(guides: [g], cap: 50);
      expect(index.keys.toSet(), {2025, 2026});

      final y26 = index[2026]!;
      expect(y26.placements.keys.toSet(), {'g:gx:p1', 'g:gx:p2'});
      // 两张同位置照片聚一团（当年成员都在）
      expect(y26.clusters, isNotEmpty);
      expect(y26.clusters.expand((c) => c.members).toSet(),
          {'g:gx:p1', 'g:gx:p2'});

      // 仓库读回（year 记录从不覆盖照片，也从磁盘读取一致）
      final loaded = await WallPhotoRepository(storage).loadYears();
      expect(loaded.keys.toSet(), {2025, 2026});
      expect(
          loaded[2026]!.placements.keys.toSet(), {'g:gx:p1', 'g:gx:p2'});
      expect(loaded[2025]!.placements.keys, ['w:wOld']);
      // 快照里的摆放与白板同 seed 一致
      final pts = service.collectPoints(guides: [g], ledger: ledger, cap: 50);
      final layout = layoutWallPhotos(pts, seed: kWallLayoutSeed);
      final p26 = loaded[2026]!;
      expect(
        p26.placements['g:gx:p1']!.x,
        closeTo(
          layout.placements
              .firstWhere((p) => p.uid == 'g:gx:p1')
              .x,
          1e-9,
        ),
      );
    });
  });

  group('WallPhoto 模型', () {    test('JSON round-trip：可选字段保真', () {
      final w = WallPhoto(
        id: 'wp1',
        lat: 31.23,
        lng: 121.47,
        guideId: 'g9',
        takenAt: DateTime(2026, 1, 2, 3, 4),
        file: 'pics/photowall/p_x.jpg',
        thumb: 'pics/photowall/thumbs/t_x.jpg',
        name: 'x.jpg',
      );
      final back = WallPhoto.fromJson(w.toJson());
      expect(back.id, w.id);
      expect(back.lat, w.lat);
      expect(back.lng, w.lng);
      expect(back.guideId, w.guideId);
      expect(back.file, w.file);
      expect(back.thumb, w.thumb);
      expect(back.name, w.name);
      expect(back.takenAt, w.takenAt);

      // 最小字段（无定位未归属）
      final b = WallPhoto.fromJson({
        'id': 'wp2',
        'takenAt': '2026-02-03T04:05:00.000',
        'file': 'pics/y.jpg',
      });
      expect(b.hasGps, false);
      expect(b.guideId, isNull);
      expect(b.thumb, '');
    });

    test('copyWith 定位补拍后归属变化可用（原值不变）', () {
      final w = WallPhoto(id: 'wp3', takenAt: DateTime(2026, 1));
      final bound = w.copyWith(lat: 1.0, lng: 2.0, guideId: 'g1');
      expect(bound.hasGps, true);
      expect(bound.guideId, 'g1');
      expect(w.hasGps, false);
    });
  });
}
