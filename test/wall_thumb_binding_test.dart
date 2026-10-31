import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/core/utils/thumb_binding.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/wall_photo.dart';

/// 缩略图绑定锁（v8.3）——「文件名 ↔ 缩略图名」数据口径回归。
///
/// 背景：相册库/地图标记曾按 Widget 位置复用缩略缓存，新条目入册
/// （拍摄时间倒序插顶）或缩放重排后既有照片/视频缩略错误串显。
/// 修复口径（用户拍板）：配对以**数据形式锁死**——条目自带
/// file+thumb，渲染按 uid+配对取用，绝不依赖位序/index。
void main() {
  group('锁定配对解析（resolveThumbBinding / 模型 thumbBinding）', () {
    test('视频有首帧 → 锁定首帧缩略，与视频原件无关', () {
      final w = WallPhoto(
          id: 'wp_a',
          takenAt: DateTime(2026, 10, 5, 15, 28),
          kind: 'video',
          file: 'pics/videos/v_7f07eacd.mp4',
          thumb: 'pics/videos/vt_7f07eacd.jpg');
      expect(w.thumbBinding, 'pics/videos/vt_7f07eacd.jpg');
      expect(
        resolveThumbBinding(
            isVideo: true,
            thumb: 't.jpg',
            file: 'v.mp4'),
        't.jpg',
      );
    });

    test('视频缺首帧 → 锁定为空串，绝不退化到视频原件路径（Invalid image data 防线）', () {
      final w = WallPhoto(
          id: 'wp_b',
          takenAt: DateTime(2026, 10, 5),
          kind: 'video',
          file: 'pics/videos/v_1.mp4');
      expect(w.thumbBinding, isEmpty);
      expect(
        resolveThumbBinding(isVideo: true, thumb: '', file: 'v.mp4'),
        isEmpty,
      );
    });

    test('照片有缩略 → 锁定缩略；缺缩略 → 原图即缩略（历史数据口径）', () {
      final p1 = PhotoItem(
          id: 'ph_a',
          takenAt: DateTime(2026, 10, 1),
          file: 'pics/photowall/p_1.jpg',
          thumb: 'pics/photowall/t_1.jpg');
      final p2 = PhotoItem(
          id: 'ph_b',
          takenAt: DateTime(2026, 10, 2),
          file: 'pics/photowall/p_2.jpg');
      expect(p1.thumbBinding, 'pics/photowall/t_1.jpg');
      expect(p2.thumbBinding, 'pics/photowall/p_2.jpg');
      // WallPhoto 同口径
      final w = WallPhoto(
          id: 'wp_c',
          takenAt: DateTime(2026, 10, 3),
          file: 'pics/photowall/p_2181.jpg');
      expect(w.thumbBinding, 'pics/photowall/p_2181.jpg');
    });

    test('JSON 往返不动配对——锁定口径随数据落盘，加载时即锁死', () {
      final w = WallPhoto(
          id: 'wp_mvhqlcz3_jd35au',
          takenAt: DateTime(2026, 10, 5, 15, 28),
          file: 'pics/photowall/p_2181023495.jpg',
          thumb: 'pics/photowall/t_2181023495.jpg');
      final back = WallPhoto.fromJson(w.toJson());
      expect(back.thumbBinding, w.thumbBinding);
      expect(back.file, w.file);
      expect(back.thumb, w.thumb);

      final v = WallPhoto(
          id: 'wv_mvhsrkqw_gaqh9b',
          takenAt: DateTime(2026, 10, 5, 15, 30),
          kind: 'video',
          file: 'pics/videos/v_7f07eacd.mp4',
          thumb: 'pics/videos/vt_7f07eacd.jpg',
          durationMs: 45000);
      final vb = WallPhoto.fromJson(v.toJson());
      expect(vb.isVideo, isTrue);
      expect(vb.thumbBinding, v.thumbBinding);
    });
  });

  group('插入/排序不串绑（新条目入册场景）', () {
    // 相册账本「拍摄时间倒序」：新拍摄条目插到顶部，既有条目整体后移。
    // 锁定口径断言：无论位序怎么变，uid → 缩略配对恒等于其自带字段。
    test('新条目插顶后，既有条目的 uid→配对逐一不变', () {
      final old = [
        WallPhoto(
            id: 'wp_001',
            takenAt: DateTime(2026, 10, 3, 9, 0),
            file: 'pics/photowall/p_001.jpg',
            thumb: 'pics/photowall/t_001.jpg'),
        WallPhoto(
            id: 'wp_002',
            takenAt: DateTime(2026, 10, 3, 8, 0),
            file: 'pics/photowall/p_002.jpg',
            thumb: 'pics/photowall/t_002.jpg'),
        WallPhoto(
            id: 'wv_003',
            takenAt: DateTime(2026, 10, 3, 7, 0),
            kind: 'video',
            file: 'pics/videos/v_003.mp4',
            thumb: 'pics/videos/vt_003.jpg',
            durationMs: 30000),
      ];

      Map<String, String> byUid(List<WallPhoto> all) => {
            for (final w in all) w.id: w.thumbBinding,
          };

      final before = byUid(old);
      // 新条目（拍摄时间更新）插入账本 → 倒序后插顶
      final fresh = WallPhoto(
          id: 'wp_fresh',
          takenAt: DateTime(2026, 10, 23, 12, 0),
          file: 'pics/photowall/p_fresh.jpg',
          thumb: 'pics/photowall/t_fresh.jpg');
      final after = byUid([...old, fresh]..sort((a, b) =>
          b.takenAt.compareTo(a.takenAt)));
      // 位序全变，但既有条目按 uid 查得的配对不变
      for (final e in before.entries) {
        expect(after[e.key], e.value,
            reason: '插入新条目后 ${e.key} 的缩略配对不得串绑');
      }
      expect(after[fresh.id], 'pics/photowall/t_fresh.jpg');
    });

    test('排序方向翻转（升序/降序）同样不改变 uid→配对', () {
      final list = [
        WallPhoto(
            id: 'wp_x',
            takenAt: DateTime(2026, 10, 1),
            file: 'f_x.jpg',
            thumb: 't_x.jpg'),
        WallPhoto(
            id: 'wp_y',
            takenAt: DateTime(2026, 10, 2),
            file: 'f_y.jpg',
            thumb: 't_y.jpg'),
      ];
      final asc = {
        for (final w in (list..sort((a, b) => a.takenAt.compareTo(b.takenAt))))
          w.id: w.thumbBinding,
      };
      final desc = {
        for (final w in (list..sort((a, b) => b.takenAt.compareTo(a.takenAt))))
          w.id: w.thumbBinding,
      };
      expect(asc, desc, reason: '升序/降序两条路径逐键同值');
    });

    test('绑定键：同 uid+配对 → 同键；uid 或配对任一变 → 键变（防串断言）', () {
      const uid = 'wp_001';
      final k = thumbBindingKey(uid, 't_001.jpg');
      expect(thumbBindingKey(uid, 't_001.jpg'), k); // 稳定
      expect(thumbBindingKey('wp_002', 't_001.jpg'), isNot(k)); // uid 变
      expect(thumbBindingKey(uid, 't_002.jpg'), isNot(k)); // 配对变
      // 空配对（如视频缺首帧）以 `|` 收尾，与任何非空路径配对不撞车
      final emptyKey = thumbBindingKey('wv_9', '');
      expect(emptyKey, 'tb|wv_9|');
      expect(thumbBindingKey('wv_9', '_'), isNot(emptyKey));
    });
  });
}
