import 'package:flutter_test/flutter_test.dart';

import 'package:atma_book/data/models/guide.dart';

/// v7.0 S1：PhotoItem 新增 kind / durationMs —— 视频条目与旧数据兼容回归
void main() {
  test('视频条目：kind/durationMs 序列化往返 + isVideo', () {
    final p = PhotoItem(
      id: 'vd_test',
      takenAt: DateTime(2026, 10, 21, 12, 0),
      kind: 'video',
      durationMs: 95500,
      file: 'pics/videos/v_1a2b3c4d.mp4',
      thumb: 'pics/photowall/thumbs/t_1a2b3c4d.jpg',
      name: '环湖骑行',
    );

    final j = p.toJson();
    expect(j['kind'], 'video');
    expect(j['durationMs'], 95500);

    final back = PhotoItem.fromJson(j);
    expect(back.kind, 'video');
    expect(back.isVideo, isTrue);
    expect(back.durationMs, 95500);
    expect(back.file, 'pics/videos/v_1a2b3c4d.mp4');
    expect(back.name, '环湖骑行');
  });

  test('旧数据兼容：无 kind 键 → 默认照片、时长 0', () {
    final old = PhotoItem.fromJson({
      'id': 'ph_old',
      'takenAt': '2025-01-02T09:00:00.000',
      'gradientIndex': 2,
      'file': 'pics/photowall/p_old.jpg',
      'thumb': 'pics/photowall/thumbs/t_old.jpg',
      'name': '日出',
    });
    expect(old.kind, 'photo');
    expect(old.isVideo, isFalse);
    expect(old.durationMs, 0);

    // 旧数据 round trip 不新增键（保持 JSON 稳定）
    final j = old.toJson();
    expect(j.containsKey('kind'), isFalse);
    expect(j.containsKey('durationMs'), isFalse);
  });
}
