import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/data/models/wall_photo.dart';
import 'package:atma_book/data/seed_data.dart';
import 'package:atma_book/services/share_service.dart';
import 'package:atma_book/services/video_transcoder.dart';

import 'share_service_test.dart' show MemoryStorage;

/// v7.0 S3：分享视频链路
/// - 目标尺寸规则（横 720p / 竖 720 宽）；
/// - v2 包解析：videos/ 条目放行、videos.json 元数据可读；
/// - 导入落地：视频成为**攻略内** kind=video 的 PhotoItem（不进地理相册）；
/// - v1 旧包兼容：无 videos.json 也能正常导入。
void main() {
  group('VideoTranscoder.targetSizeFor（目标尺寸规则）', () {
    test('横屏 → 高 720、宽自适应（-2）', () {
      final (w, h) = VideoTranscoder.targetSizeFor(3840, 2160);
      expect(w, -2);
      expect(h, 720);
    });

    test('竖屏 → 宽 720、高自适应（-2）', () {
      final (w, h) = VideoTranscoder.targetSizeFor(1080, 1920);
      expect(w, 720);
      expect(h, -2);
    });

    test('正方形 → 竖向规则（宽 720）', () {
      final (w, h) = VideoTranscoder.targetSizeFor(1000, 1000);
      expect(h, -2);
      expect(w, 720);
    });

    test('非法输入兜底 1280×720', () {
      final (w, h) = VideoTranscoder.targetSizeFor(0, 0);
      expect(w, 1280);
      expect(h, 720);
    });
  });

  group('v2 包：videos/ 条目与导入落地', () {
    /// 手工构造含视频的 v2 包
    (Uint8List, Uint8List, List<int>) buildV2Zip() {
      final guide = SeedData.buildDemoGuide();
      final videoBytes = Uint8List.fromList([1, 2, 3, 4, 5]); // 非真实 mp4（解析层不做编解码）
      final thumbBytes = Uint8List.fromList([9, 8, 7, 6]);
      final archive = ar.Archive()
        ..addFile(ar.ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'format': 'tgshare',
              'formatVersion': 2,
              'fingerprint': 'a' * 16,
            })))
        ..addFile(ar.ArchiveFile.string(
            'guide.json', jsonEncode(guide.toJson())))
        ..addFile(ar.ArchiveFile.bytes('videos/wv_test1.mp4', videoBytes))
        ..addFile(ar.ArchiveFile.bytes('thumbs/wv_test1.jpg', thumbBytes))
        ..addFile(
            ar.ArchiveFile.string(
                'videos.json',
                jsonEncode([
                  {
                    'id': 'wv_test1',
                    'takenAt': '2026-10-20T08:00:00.000Z',
                    'lat': 30.25,
                    'lng': 120.15,
                    'name': '西湖边拍的视频',
                    'durationMs': 2453,
                  }
                ])));
      final bytes = Uint8List.fromList(ar.ZipEncoder().encode(archive));
      return (bytes, videoBytes, thumbBytes);
    }

    test('v2 包解析成功：videos.json 元数据完整读出', () {
      final (zip, _, _) = buildV2Zip();
      final parsed = ShareService.parseShare(zip);
      expect(parsed, isNotNull);
      expect(parsed!.videosMeta, hasLength(1));
      final m = parsed.videosMeta.first;
      expect(m['id'], 'wv_test1');
      expect(m['name'], '西湖边拍的视频');
      expect(m['durationMs'], 2453);
      expect(m['lat'], 30.25);
      expect(m['takenAt'], '2026-10-20T08:00:00.000Z');
    });

    test('v1 旧包兼容：无 videos.json 照常导入（videosMeta 空）', () {
      final guide = SeedData.buildDemoGuide();
      final archive = ar.Archive()
        ..addFile(ar.ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'format': 'tgshare',
              'formatVersion': 1,
              'fingerprint': 'b' * 16,
            })))
        ..addFile(ar.ArchiveFile.string(
            'guide.json', jsonEncode(guide.toJson())));
      final parsed = ShareService.parseShare(
          Uint8List.fromList(ar.ZipEncoder().encode(archive)));
      expect(parsed, isNotNull);
      expect(parsed!.videosMeta, isEmpty);
    });

    test('videos/ 白名单外的扩展名拒收（如 videos/x.exe）', () {
      final guide = SeedData.buildDemoGuide();
      final archive = ar.Archive()
        ..addFile(ar.ArchiveFile.string(
            'manifest.json',
            jsonEncode({
              'format': 'tgshare',
              'formatVersion': 2,
            })))
        ..addFile(ar.ArchiveFile.string(
            'guide.json', jsonEncode(guide.toJson())))
        ..addFile(ar.ArchiveFile.bytes('videos/x.exe', [1]));
      expect(
          ShareService.parseShare(
              Uint8List.fromList(ar.ZipEncoder().encode(archive))),
          isNull);
    });

    test('应用导入：视频成为攻略内 kind=video 的 PhotoItem，文件落盘到攻略目录',
        () async {
      final (zip, videoBytes, thumbBytes) = buildV2Zip();
      final storage = MemoryStorage();
      final service = ShareService(storage);

      final parsed = ShareService.parseShare(zip)!;
      final applied = await service.applyImport(parsed);
      final g = applied!.guide;

      final videos = [for (final p in g.photos) if (p.isVideo) p];
      expect(videos, hasLength(1));
      final v = videos.first;
      expect(v.kind, 'video');
      expect(v.durationMs, 2453);
      expect(v.name, '西湖边拍的视频');
      expect(v.lat, 30.25);
      expect(v.lng, 120.15);
      expect(v.file, startsWith('pics/${g.id}/shared/'));
      expect(v.file, endsWith('.mp4'));
      expect(v.thumb, startsWith('pics/${g.id}/shared/'));
      expect(storage.blobs[v.file], videoBytes);
      expect(storage.blobs[v.thumb], thumbBytes);
      // 时间戳保留
      expect(v.takenAt.year, 2026);

      // 不进地理相册账本：账本仓储独立于本次导入，无写入动作（由调用方决定），
      // 这里仅断言攻略内条目与路径——账本写入不发生在 applyImport 内。
    });
  });

  group('指纹计入视频锚段（S4）', () {
    WallPhoto mkVideo(String id, String file) => WallPhoto(
          id: id,
          file: file,
          takenAt: DateTime(2026, 10, 20),
        );

    test('无视频：与 v6.0 口径一致（仅 guide 内容）', () {
      final g = SeedData.buildDemoGuide();
      final f1 = ShareService.fingerprintOf(g);
      final f2 = ShareService.fingerprintOf(g, videos: const []);
      expect(f1, f2);
      expect(f1.length, 16);
    });

    test('含视频 ≠ 不含视频（视频换代指纹）；重复计算稳定', () {
      final g = SeedData.buildDemoGuide();
      final v = [mkVideo('wv_a', 'pics/videos/v_hash1.mp4')];
      final base = ShareService.fingerprintOf(g);
      final withV1 = ShareService.fingerprintOf(g, videos: v);
      expect(withV1, isNot(base));
      expect(ShareService.fingerprintOf(g, videos: v), withV1);
    });

    test('条目顺序无关（排序锚段）', () {
      final g = SeedData.buildDemoGuide();
      final a = [
        mkVideo('wv_a', 'pics/videos/v_h1.mp4'),
        mkVideo('wv_b', 'pics/videos/v_h2.mp4'),
      ];
      final b = a.reversed.toList();
      expect(
        ShareService.fingerprintOf(g, videos: a),
        ShareService.fingerprintOf(g, videos: b),
      );
    });

    test('内容哈希变化 → 指纹变化；改名/换时长不影响', () {
      final g = SeedData.buildDemoGuide();
      final v1 = [mkVideo('wv_a', 'pics/videos/v_h1.mp4')];
      final v2 = [
        mkVideo('wv_a', 'pics/videos/v_h2.mp4'),
      ];
      expect(
        ShareService.fingerprintOf(g, videos: v1),
        isNot(ShareService.fingerprintOf(g, videos: v2)),
      );
      // 仅名称/时长变化（不影响已打包内容）→ 指纹不变
      final renamed = mkVideo('wv_a', 'pics/videos/v_h1.mp4');
      expect(
        ShareService.fingerprintOf(g, videos: v1),
        ShareService.fingerprintOf(
            g, videos: [renamed.copyWith(name: '改名', durationMs: 999)]),
      );
    });
  });
}
