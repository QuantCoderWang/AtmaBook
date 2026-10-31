import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/wall_photo.dart';
import 'package:atma_book/data/seed_data.dart';
import 'package:atma_book/services/share_bundle_service.dart';
import 'package:atma_book/services/share_service.dart';
import 'package:atma_book/services/share_temp.dart' show deleteTempWorkDir;

import 'share_service_test.dart' show MemoryStorage;

/// 生成一张 48x48 的测试 PNG（与 share_service_test 同口径）
Uint8List _fakePng() {
  final image = img.Image(width: 48, height: 48);
  for (var y = 0; y < 48; y++) {
    for (var x = 0; x < 48; x++) {
      image.setPixelRgba(x, y, x * 5, y * 5, (x + y) * 2, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// 给照片补上文件路径（与 share_service_test 的 _withPhotoFiles 同口径；
/// 该 helper 为库私有，此处按需内联）
Guide _withPhotoFiles(Guide guide, Map<String, String> fileOf,
    {String? thumbOf}) {
  final photos = [
    for (final p in guide.photos)
      fileOf.containsKey(p.id)
          ? p.copyWith(file: fileOf[p.id]!, thumb: thumbOf ?? '')
          : p,
  ];
  return guide.copyWith(photos: photos);
}

void main() {
  group('ShareBundleService（v8.2 全量导出包）', () {
    /// 组装两篇带媒体（攻略内照片 + 账本归属照片/视频）的演示攻略
    (MemoryStorage, List<Guide>, List<WallPhoto>) fixture() {
      final storage = MemoryStorage();
      final png = _fakePng();
      final videoBytes = Uint8List.fromList(List.generate(16, (i) => i));
      storage.blobs['pics/photowall/p1.png'] = png;
      storage.blobs['pics/photowall/p1_t.png'] = png;
      storage.blobs['pics/photowall/p2.png'] = png;
      storage.blobs['pics/photowall/p2_t.png'] = png;
      storage.blobs['pics/videos/v_a.mp4'] = videoBytes;
      storage.blobs['pics/videos/v_a_t.jpg'] = png;

      final g1Raw = SeedData.buildDemoGuide();
      final g2Raw = SeedData.buildDemoGuide().copyWith(title: '第二条攻略');
      final g1 = _withPhotoFiles(g1Raw, {
        g1Raw.photos.first.id: 'pics/photowall/p1.png',
      }, thumbOf: 'pics/photowall/p1_t.png');
      final g2 = _withPhotoFiles(g2Raw, {
        g2Raw.photos.first.id: 'pics/photowall/p2.png',
      }, thumbOf: 'pics/photowall/p2_t.png');
      final guides = [g1, g2];

      // 账本：g1、g2 各归属 1 张照片；g2 另归属 1 条视频
      // （v8.1 口径：账本归属媒体不写 Guide.photos）
      final ledger = <WallPhoto>[
        WallPhoto(
          id: 'wp_album_g1',
          guideId: g1.id,
          takenAt: DateTime(2026, 10, 6, 8, 0),
          file: 'pics/photowall/p2.png',
          thumb: 'pics/photowall/p2_t.png',
        ),
        WallPhoto(
          id: 'wp_album_g2',
          guideId: g2.id,
          takenAt: DateTime(2026, 10, 5, 15, 28),
          file: 'pics/photowall/p1.png',
          thumb: 'pics/photowall/p1_t.png',
        ),
        WallPhoto(
          id: 'wv_album_g2',
          kind: 'video',
          guideId: g2.id,
          takenAt: DateTime(2026, 10, 5, 15, 28),
          file: 'pics/videos/v_a.mp4',
          thumb: 'pics/videos/v_a_t.jpg',
          name: 'VID_A',
        ),
      ];
      return (storage, guides, ledger);
    }

    /// 读外层大包全部条目（单测直读文件）→ 删除临时目录
    Future<Map<String, Uint8List>> readBundle(ShareExportResult r) async {
      final f = File(r.tempPath!);
      final bytes = await f.readAsBytes();
      final dir = r.tempPath!.substring(0, r.tempPath!.lastIndexOf('/'));
      await deleteTempWorkDir(dir);
      final decoder = _unzip(bytes);
      return decoder;
    }

    Future<String?> innerName(Map<String, Uint8List> zip, int index) async {
      final manifest = jsonDecode(utf8.decode(zip['manifest.json']!)) as Map;
      return (manifest['guides'] as List)[index] as String?;
    }

    test('外层容器：manifest + 2 内层 .tgshare（存储式条目，序号命名）', () async {
      final (storage, guides, ledger) = fixture();
      final service = ShareBundleService(storage);
      final progress = <String>[];
      final result = await service.buildAll(
        guides: guides,
        ledger: ledger,
        onProgress: (done, total, title) =>
            progress.add('$done/$total:$title'),
      );
      expect(result, isNotNull);
      expect(result!.filename, endsWith('.tgbundle'));
      expect(result.sizeBytes, greaterThan(0));
      expect(result.fingerprint, ''); // 全量包不做攻略级指纹
      expect(progress.length, 2); // 逐篇进度
      expect(progress[0], startsWith('1/2:'));

      final zip = await readBundle(result);
      final names = jsonDecode(utf8.decode(zip['manifest.json']!))
          ['guides'] as List;
      expect(names.length, 2);
      for (final n in names) {
        expect(n, matches(RegExp(r'^\d{3}_.*\.tgshare$')));
        expect(zip.containsKey(n), isTrue); // 内层条目确实在包中
      }
      expect(zip.keys, hasLength(3)); // manifest + 2 内层
    });

    test('内层包质量：逐条 parseShare 通过，账本归属照片/视频随篇入包', () async {
      final (unusedStorage, guides, ledger) = fixture();
      final service = ShareBundleService(unusedStorage);
      final result = await service.buildAll(guides: guides, ledger: ledger);
      final zip = await readBundle(result!);

      final name1 = await innerName(zip, 0);
      final name2 = await innerName(zip, 1);
      final inner1 = ShareService.parseShare(zip[name1!]!)!;
      final inner2 = ShareService.parseShare(zip[name2!]!)!;

      // 两篇内层均为原片模式
      expect(inner1.manifest['policy'], 'original');
      expect(inner2.manifest['policy'], 'original');

      // 第 1 篇：攻略内照片 + 账本归属照片都进 guide.json
      expect(inner1.guide.photos.any((p) => p.id == 'wp_album_g1'), isTrue);
      // 第 2 篇：攻略内照片 + 账本照片 + 账本视频
      expect(inner2.guide.photos.any((p) => p.id == 'wp_album_g2'), isTrue);
      expect(inner2.videosMeta.any((v) => v['id'] == 'wv_album_g2'), isTrue);
    });

    test('导入链：逐条复原成功；重复导入全部查重跳过；取消中止', () async {
      final (storage, unusedGuides, ledger) = fixture();
      final service = ShareBundleService(storage);
      final result = await service.buildAll(guides: unusedGuides, ledger: ledger);
      final bundlePath = result!.tempPath!;

      // —— 第一次导入：2 篇全部复原为新攻略 ——
      final imported = <Guide>[];
      final firstFingerprints = <String>{};
      final report = await service.importAll(
        absPath: bundlePath,
        onGuide: (parsed) async {
          firstFingerprints.add(parsed.fingerprint); // 落库 shareKey 同源
          final imp = await ShareService(storage).applyImport(parsed);
          if (imp == null) return ShareBundleGuideResult.cancelled;
          imported.add(imp.guide);
          return ShareBundleGuideResult.applied;
        },
      );
      expect(report, isNotNull);
      expect(report!.applied, 2);
      expect(report.skipped, 0);
      expect(report.failed, 0);
      expect(imported.length, 2);
      // 复原出的攻略：账本归属照片成为攻略内照片（重映射，文件非空）
      expect(
          imported[1].photos.where((p) => p.file.isNotEmpty).length,
          greaterThanOrEqualTo(2));

      expect(firstFingerprints.length, 2);

      // —— 二次导入（模拟已导入过：applyImport 落库的 shareKey = 语义上包内
      //     manifest 指纹，首页 hasShareKey 比对的就是它；命中全部跳过）——
      final report2 = await service.importAll(
        absPath: bundlePath,
        onGuide: (parsed) async =>
            firstFingerprints.contains(parsed.fingerprint)
                ? ShareBundleGuideResult.skipped
                : ShareBundleGuideResult.applied,
      );
      expect(report2!.applied, 0);
      expect(report2.skipped, 2);

      // —— 取消：第一篇即中止 ——
      final report3 = await service.importAll(
        absPath: bundlePath,
        onGuide: (parsed) async => ShareBundleGuideResult.cancelled,
      );
      expect(report3!.applied, 0);
      expect(report3.cancelled, isTrue);

      final dir = bundlePath.substring(0, bundlePath.lastIndexOf('/'));
      await deleteTempWorkDir(dir);
    });

    test('非 .tgbundle 结构拒收：单包（tgshare）导入返回 null', () async {
      final share = ShareService(MemoryStorage());
      final single = await share.build(
        guide: SeedData.buildDemoGuide(),
        includePhotos: false,
        watermarkText: '',
        // 原片模式才有流式临时文件产物（水印单包在内存中——不针对本项拒收场景）
        policy: ShareExportPolicy.original,
      );
      final bundle = ShareBundleService(MemoryStorage());
      final report = await bundle.importAll(
        absPath: single!.tempPath!,
        onGuide: (_) async => ShareBundleGuideResult.cancelled,
      );
      expect(report, isNull); // 外层 manifest.format != tgbundle
      final dir = single.tempPath!.substring(
          0, single.tempPath!.lastIndexOf('/'));
      await deleteTempWorkDir(dir);
    });
  });
}

Map<String, Uint8List> _unzip(Uint8List zipBytes) {
  final out = <String, Uint8List>{};
  final archive = ar.ZipDecoder().decodeBytes(zipBytes);
  for (final f in archive.files) {
    if (f.isFile) {
      final data = f.readBytes() ?? Uint8List(0);
      out[f.name] = Uint8List.fromList(data);
    }
  }
  return out;
}
