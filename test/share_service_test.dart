import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:atma_book/core/io/storage_adapter.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/wall_photo.dart';
import 'package:atma_book/data/seed_data.dart';
import 'package:atma_book/services/share_service.dart';
import 'package:atma_book/services/share_temp.dart'
    show deleteTempWorkDir;

/// 内存版存储适配（单测专用；支持字节读写）
class MemoryStorage extends StorageAdapter {
  final Map<String, String> texts = {};
  final Map<String, Uint8List> blobs = {};

  @override
  String get locationLabel => 'memory';

  @override
  Future<bool> exists(String rel) async =>
      texts.containsKey(rel) || blobs.containsKey(rel);

  @override
  Future<String> readText(String rel) async {
    final v = texts[rel];
    if (v == null) throw StateError('missing $rel');
    return v;
  }

  @override
  Future<void> writeText(String rel, String content) async {
    texts[rel] = content;
  }

  @override
  Future<void> deleteFile(String rel) async {
    texts.remove(rel);
    blobs.remove(rel);
  }

  @override
  Future<List<String>> listFiles(String dirRel) async {
    final keys = [...texts.keys, ...blobs.keys];
    final out = <String>[];
    for (final k in keys) {
      if (k.startsWith('$dirRel/')) out.add(k);
    }
    return out;
  }

  @override
  Future<Uint8List?> readBytes(String rel) async => blobs[rel];

  @override
  Future<void> writeBytes(String rel, Uint8List bytes) async {
    blobs[rel] = bytes;
  }

  @override
  Future<void> deleteDir(String dirRel) async {
    texts.removeWhere((k, _) => k.startsWith('$dirRel/'));
    blobs.removeWhere((k, _) => k.startsWith('$dirRel/'));
  }
}

/// 生成一张 48x48 的测试 PNG（含颜色变化供编码/解码管线校验）
Uint8List _fakePng() {
  final image = img.Image(width: 48, height: 48);
  for (var y = 0; y < 48; y++) {
    for (var x = 0; x < 48; x++) {
      image.setPixelRgba(x, y, x * 5, y * 5, (x + y) * 2, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ShareService.build（S1 导出链）', () {
    test('不含照片：仅 manifest + guide.json 两个条目，manifest 字段正确',
        () async {
          final service = ShareService(MemoryStorage());
          final result = await service.build(
            guide: SeedData.buildDemoGuide(),
            includePhotos: false,
            watermarkText: '',
          );

          expect(result, isNotNull);
          expect(result!.includesPhotos, isFalse);
          expect(result.filename, contains('.tgshare'));

          final zip = result.bytes;
          final archive = _unzip(zip);
          expect(archive.keys, containsAll(['manifest.json', 'guide.json']));
          expect(archive.containsKey('cover.jpg'), isFalse);

          final manifest =
              jsonDecode(utf8.decode(archive['manifest.json']!)) as Map;
          expect(manifest['format'], 'tgshare');
          expect(manifest['formatVersion'], 3);
          expect(manifest['policy'], 'watermarked');
          expect(manifest['includesPhotos'], false);
          expect((manifest['fingerprint'] as String).length, 16);

          final guideJson =
              jsonDecode(utf8.decode(archive['guide.json']!)) as Map;
          expect(guideJson['id'], SeedData.buildDemoGuide().id);
        });

    test('含照片：photos/<id>.jpg 与 thumbs/<id>.jpg 双条目 + 可解码 JPEG',
        () async {
          final storage = MemoryStorage();
          final png = _fakePng();
          storage.blobs['pics/photowall/p1.jpg'] = png;
          storage.blobs['pics/photowall/p1_thumb.jpg'] = png;

          // 演示攻略的第一张照片补上文件路径
          final guide = SeedData.buildDemoGuide();
          final patched = _withPhotoFiles(guide, {
            guide.photos.first.id: 'pics/photowall/p1.jpg',
          }, thumbOf: 'pics/photowall/p1_thumb.jpg');

          final service = ShareService(storage);
          final result = await service.build(
            guide: patched,
            includePhotos: true,
            watermarkText: '',
          );

          expect(result, isNotNull);
          final archive = _unzip(result!.bytes);
          expect(archive.containsKey('photos/${guide.photos.first.id}.jpg'),
              isTrue);
          expect(archive.containsKey('thumbs/${guide.photos.first.id}.jpg'),
              isTrue);

          // 输出须为合法 JPEG
          final photoBytes = archive['photos/${guide.photos.first.id}.jpg']!;
          final decoded = img.decodeJpg(photoBytes);
          expect(decoded, isNotNull);
          expect(decoded!.width, greaterThan(0));
        });

    test('照片文件缺失：跳过不中断（skippedCount 计数）', () async {
      final guide = SeedData.buildDemoGuide();
      final patched = _withPhotoFiles(guide, {
        guide.photos.first.id: 'pics/photowall/missing.jpg',
      });
      final service = ShareService(MemoryStorage());
      final result = await service.build(
        guide: patched,
        includePhotos: true,
        watermarkText: '',
      );

      expect(result, isNotNull);
      final archive = _unzip(result!.bytes);
      expect(archive.containsKey('photos/${guide.photos.first.id}.jpg'),
          isFalse);
      expect(result.skippedCount, greaterThan(0));
    });

    test('指纹稳定：相同内容两次导出指纹一致', () async {
      final service = ShareService(MemoryStorage());
      final r1 = await service.build(
          guide: SeedData.buildDemoGuide(),
          includePhotos: false,
          watermarkText: '');
      final r2 = await service.build(
          guide: SeedData.buildDemoGuide(),
          includePhotos: false,
          watermarkText: '');
      expect(r1!.fingerprint, r2!.fingerprint);
    });

    test('isCancelled：进行中取消 → 返回 null', () async {
      final storage = MemoryStorage();
      final png = _fakePng();
      storage.blobs['pics/photowall/p1.jpg'] = png;
      final guide = SeedData.buildDemoGuide();
      final patched = _withPhotoFiles(guide, {
        guide.photos.first.id: 'pics/photowall/p1.jpg',
      });

      final service = ShareService(storage);
      final result = await service.build(
        guide: patched,
        includePhotos: true,
        watermarkText: '',
        isCancelled: () => true,
      );
      expect(result, isNull);
    });
  });

  group('ShareService 导入链（S2）', () {
    test('Guide.shared / shareKey JSON round-trip（旧数据缺键默认 false）', () {
      final base = SeedData.buildDemoGuide();
      expect(base.shared, isFalse);

      final j = base.copyWith(shared: true).toJson();
      expect(j['shared'], true);

      final parsed = Guide.fromJson(
          jsonDecode(jsonEncode(base.toJson()))); // 无 shared 键
      expect(parsed.shared, isFalse);

      final withKey = Guide.fromJson(jsonDecode(jsonEncode({
        ...(base.toJson() as Map).cast<String, dynamic>(),
        'shared': true,
        'shareKey': 'abc123',
      })));
      expect(withKey.shared, isTrue);
      expect(withKey.shareKey, 'abc123');
    });

    test('白名单：含穿越条目的 ZIP 拒收；非 ZIP 拒收', () {
      // 构造带穿越条目的 zip
      final bad = ar.ZipEncoder().encode(ar.Archive()
        ..addFile(ar.ArchiveFile.string('../evil.json', '{}')));
      expect(ShareService.parseShare(Uint8List.fromList(bad)), isNull);
      // 非 ZIP 字节（无 PK 魔数）
      expect(ShareService.parseShare(Uint8List.fromList(utf8.encode('hello'))),
          isNull);
    });

    test('导出 → 解析 → 重映射落盘：新 id 互不冲突、引用完整、shared=true',
        () async {
          final storage = MemoryStorage();
          final png = _fakePng();
          storage.blobs['pics/photowall/p1.jpg'] = png;
          storage.blobs['pics/photowall/p1_thumb.jpg'] = png;
          storage.blobs['pics/markers/mi1.jpg'] = png;

          final demo = SeedData.buildDemoGuide();
          final patched = _withPhotoFiles(demo, {
            demo.photos.first.id: 'pics/photowall/p1.jpg',
          }, thumbOf: 'pics/photowall/p1_thumb.jpg')
              .copyWith(
            photos: [
              for (final p in _withPhotoFiles(demo, {
                demo.photos.first.id: 'pics/photowall/p1.jpg',
              }, thumbOf: 'pics/photowall/p1_thumb.jpg').photos)
                p.id == demo.photos.first.id
                    ? p.copyWith(placeId: demo.markers.first.id)
                    : p,
            ],
            markers: [
              for (final m in demo.markers)
                m.id == demo.markers.first.id
                    ? m.copyWith(images: ['pics/markers/mi1.jpg'])
                    : m,
            ],
          );
          // 演示攻略首个片区包含首个标记成员（重写引用验证对象）

          // 1) 导出
          final exporter = ShareService(storage);
          final export = await exporter.build(
            guide: patched,
            includePhotos: true,
            watermarkText: '',
          );
          expect(export, isNotNull);

          // 2) 解析
          final parsed = ShareService.parseShare(export!.bytes);
          expect(parsed, isNotNull);
          expect(parsed!.fingerprint, export.fingerprint);

          // 3) 重映射落盘
          final applied = await exporter.applyImport(parsed);
          final g = applied!.guide;
          expect(g.shared, isTrue);
          expect(g.shareKey, export.fingerprint);
          expect(g.id, isNot(patched.id));
          final newMkIds = g.markers.map((m) => m.id).toSet();
          expect(newMkIds.length, patched.markers.length);
          // 片区成员引用已重写为有效新 id
          for (final z in g.clusters) {
            for (final mid in z.memberIds) {
              expect(newMkIds.contains(mid), isTrue, reason: '悬空成员 $mid');
            }
          }
          // 照片文件已写入新路径且路径字段重写
          final withFile = [for (final p in g.photos) if (p.file.isNotEmpty) p];
          expect(withFile.length, 1);
          expect(storage.blobs.containsKey(withFile.first.file), isTrue);
          // 缩略与 placeId 重写
          expect(storage.blobs.containsKey(withFile.first.thumb), isTrue);
          expect(withFile.first.placeId != null, isTrue);
          expect(newMkIds.contains(withFile.first.placeId), isTrue);
          // 标记插图重写
          final mkWithImage =
              [for (final m in g.markers) if (m.images.isNotEmpty) m].first;
          expect(mkWithImage.images.length, 1);
          expect(storage.blobs.containsKey(mkWithImage.images.first), isTrue);
          // 图片全部落在 pics/<新id>/ 下
          expect(withFile.first.file.startsWith('pics/${g.id}/'), isTrue);
          expect(mkWithImage.images.first.startsWith('pics/${g.id}/'), isTrue);
        });

    test('再次导入同文件：独立副本，两次互不冲突', () async {
      final storage = MemoryStorage();
      storage.blobs['pics/photowall/p1.jpg'] = _fakePng();
      final demo = SeedData.buildDemoGuide();
      final patched = _withPhotoFiles(demo, {
        demo.photos.first.id: 'pics/photowall/p1.jpg',
      });
      final exporter = ShareService(storage);
      final export = await exporter.build(
          guide: patched, includePhotos: true, watermarkText: '');
      final p1 = ShareService.parseShare(export!.bytes)!;
      final g1 = (await exporter.applyImport(p1))!.guide;
      final g2 = (await exporter.applyImport(p1))!.guide;

      expect(g1.id, isNot(g2.id));
      expect(g1.markers.map((m) => m.id), isNot(g2.markers.map((m) => m.id)));
      expect(g1.shareKey, g2.shareKey); // 同指纹：查重可识别
    });
  });

  group('ShareService 原片模式（v8.0 · v3 格式）', () {
    /// 读流式原片包（result.tempPath 文件）→ 解包；测试收口后删除临时目录
    Future<Map<String, Uint8List>> readOriginalZip(
        ShareExportResult r) async {
      final f = File(r.tempPath!);
      final bytes = await f.readAsBytes();
      final zip = _unzip(Uint8List.fromList(bytes));
      final dir = r.tempPath!.substring(0, r.tempPath!.lastIndexOf('/'));
      await deleteTempWorkDir(dir);
      return zip;
    }

    test('原件字节直通：PNG 照片原字节入包（无缩放/无水印），manifest policy=original',
        () async {
          final storage = MemoryStorage();
          final png = _fakePng();
          storage.blobs['pics/photowall/p1.png'] = png;
          storage.blobs['pics/photowall/p1_t.jpg'] = png;
          final guide = SeedData.buildDemoGuide();
          final patched = _withPhotoFiles(guide, {
            guide.photos.first.id: 'pics/photowall/p1.png',
          }, thumbOf: 'pics/photowall/p1_t.jpg');

          final service = ShareService(storage);
          final result = await service.build(
            guide: patched,
            includePhotos: true,
            watermarkText: '',
            policy: ShareExportPolicy.original,
          );
          expect(result, isNotNull);
          expect(result!.includesPhotos, isTrue);
          expect(result.sizeBytes, greaterThan(0));

          final zip = await readOriginalZip(result);
          // 原件直通：PNG 字节逐位一致（不缩放不加水印）
          final entry = zip['photos/${guide.photos.first.id}.png'];
          expect(entry, isNotNull);
          expect(listEquals(entry, png), isTrue);
          // 缩略恒为无水印 JPEG
          final thumb = zip['thumbs/${guide.photos.first.id}.jpg']!;
          expect(img.decodeJpg(thumb), isNotNull);

          final manifest =
              jsonDecode(utf8.decode(zip['manifest.json']!)) as Map;
          expect(manifest['formatVersion'], 3);
          expect(manifest['policy'], 'original');
          expect(manifest['watermarkText'], '');
          expect(manifest['includesPhotos'], true);
        });

    test('视频原件直通：videos/<id>.mp4 原字节入包（无需 ffmpeg 转码）', () async {
      final storage = MemoryStorage();
      final guide = SeedData.buildDemoGuide();
      final videoRel = 'pics/videos/v_abc.mp4';
      final videoBytes = Uint8List.fromList(
          [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
      storage.blobs[videoRel] = videoBytes;
      storage.blobs['pics/videos/v_abc_t.jpg'] = _fakePng();
      final w = WallPhoto(
        id: 'w_v1',
        takenAt: _fixedDate,
        guideId: 'gd_demo',
        file: videoRel,
        thumb: 'pics/videos/v_abc_t.jpg',
        name: '旅行记录',
        kind: 'video',
        durationMs: 32000,
      );

      final service = ShareService(storage);
      final result = await service.build(
        guide: guide,
        includePhotos: true,
        watermarkText: '',
        policy: ShareExportPolicy.original,
        videos: [w],
      );
      expect(result, isNotNull);
      final zip = await readOriginalZip(result!);
      final entry = zip['videos/w_v1.mp4'];
      expect(entry, isNotNull);
      expect(listEquals(entry, videoBytes), isTrue);
      final videosJson =
          jsonDecode(utf8.decode(zip['videos.json']!)) as List;
      expect(videosJson.length, 1);
      expect(videosJson.first['id'], 'w_v1');
      expect(videosJson.first['durationMs'], 32000);
    });

    test('剔除条目（excludeIds）：对应照片不出现在包内', () async {
      final storage = MemoryStorage();
      storage.blobs['pics/photowall/p1.jpg'] = _fakePng();
      final guide = SeedData.buildDemoGuide();
      final patched = _withPhotoFiles(guide, {
        guide.photos.first.id: 'pics/photowall/p1.jpg',
      });
      final service = ShareService(storage);
      final result = await service.build(
        guide: patched,
        includePhotos: true,
        watermarkText: '',
        policy: ShareExportPolicy.original,
        excludeIds: {guide.photos.first.id},
      );
      expect(result, isNotNull);
      final zip = await readOriginalZip(result!);
      expect(zip.containsKey('photos/${guide.photos.first.id}.jpg'), isFalse);
      expect(zip.containsKey('thumbs/${guide.photos.first.id}.jpg'), isFalse);
    });

    test('降质档 high：大图被缩到长边 2048 且条目改存 .jpg（副本仅存在于包内）',
        () async {
          final storage = MemoryStorage();
          final bigImage = img.Image(width: 2400, height: 80);
          for (var x = 0; x < 2400; x++) {
            for (var y = 0; y < 80; y++) {
              bigImage.setPixelRgba(x, y, x % 256, y * 3, x % 128, 255);
            }
          }
          final originalBytes =
              Uint8List.fromList(img.encodePng(bigImage));
          storage.blobs['pics/photowall/big.png'] = originalBytes;
          final guide = SeedData.buildDemoGuide();
          final patched = _withPhotoFiles(guide, {
            guide.photos.first.id: 'pics/photowall/big.png',
          });

          final service = ShareService(storage);
          final result = await service.build(
            guide: patched,
            includePhotos: true,
            watermarkText: '',
            policy: ShareExportPolicy.original,
            degrade: ShareExportDegrade.high,
          );
          expect(result, isNotNull);
          final zip = await readOriginalZip(result!);
          // 条目名为 .jpg（内容 JPEG），原 PNG 大图不出现在包内
          final entry = zip['photos/${guide.photos.first.id}.jpg'];
          expect(entry, isNotNull);
          final decoded = img.decodeJpg(entry!);
          expect(decoded, isNotNull);
          expect(decoded!.width, 2048);
          expect(decoded.height, lessThanOrEqualTo(80));
          // 降质副本 ≠ 原件字节（确有压缩处理）
          expect(listEquals(entry, originalBytes), isFalse);
        });

    test('导入链：policy=original → sharedOriginal=true，照片 rel 保留原扩展名',
        () async {
          final storage = MemoryStorage();
          final png = _fakePng();
          storage.blobs['pics/photowall/p1.png'] = png;
          final guide = SeedData.buildDemoGuide();
          final patched = _withPhotoFiles(guide, {
            guide.photos.first.id: 'pics/photowall/p1.png',
          });
          final service = ShareService(storage);
          final export = await service.build(
              guide: patched,
              includePhotos: true,
              watermarkText: '',
              policy: ShareExportPolicy.original);
          final zip = await readOriginalZip(export!);
          final parsed = ShareService.parseShare(zipBytes(zip));
          expect(parsed, isNotNull);
          expect(parsed!.isOriginal, isTrue);
          final applied = await service.applyImport(parsed);
          final g = applied!.guide;
          expect(g.shared, isTrue);
          expect(g.sharedOriginal, isTrue);
          final withFile = [for (final p in g.photos) if (p.file.isNotEmpty) p];
          expect(withFile.length, 1);
          expect(withFile.first.file.endsWith('.png'), isTrue);
          expect(storage.blobs.containsKey(withFile.first.file), isTrue);
          expect(listEquals(storage.blobs[withFile.first.file], png), isTrue);
        });

    test('指纹一致：同一攻略水印包与原片包指纹相同（导入查重跨模式可用）', () async {
      final storage = MemoryStorage();
      final png = _fakePng();
      storage.blobs['pics/photowall/p1.jpg'] = png;
      final guide = SeedData.buildDemoGuide();
      final patched = _withPhotoFiles(guide, {
        guide.photos.first.id: 'pics/photowall/p1.jpg',
      });
      final service = ShareService(storage);
      final wm = await service.build(
          guide: patched, includePhotos: true, watermarkText: '');
      final orig = await service.build(
          guide: patched,
          includePhotos: true,
          watermarkText: '',
          policy: ShareExportPolicy.original);
      expect(wm!.fingerprint, orig!.fingerprint);
      await deleteTempWorkDir(
          orig.tempPath!.substring(0, orig.tempPath!.lastIndexOf('/')));
    });

    test('白名单 v3：新扩展名获放行；穿越条目仍拒收', () {
      Uint8List pack(Map<String, List<int>> entries) {
        final ar.Archive a = ar.Archive();
        for (final e in entries.entries) {
          a.addFile(ar.ArchiveFile.bytes(e.key, Uint8List.fromList(e.value)));
        }
        return Uint8List.fromList(ar.ZipEncoder().encode(a));
      }

      final manifest = utf8.encode(jsonEncode({
        'format': 'tgshare',
        'formatVersion': 3,
        'policy': 'original',
        'fingerprint': 'x',
      }));
      final guide = utf8.encode(jsonEncode({
        'id': 'gd_x',
        'title': '原片测试',
        'photos': [
          {'id': 'ph_1', 'file': 'pics/x/shared/ph_1.png'}
        ],
      }));

      // 新扩展名（png 照片 + mov 视频 + png 封面）→ 放行
      final good = pack({
        'manifest.json': manifest,
        'guide.json': guide,
        'cover.png': utf8.encode('c'),
        'photos/ph_1.png': utf8.encode('p'),
        'videos/pv_1.mov': utf8.encode('v'),
      });
      final parsed = ShareService.parseShare(good);
      expect(parsed, isNotNull);
      expect(parsed!.isOriginal, isTrue);
      expect(parsed.entries.containsKey('photos/ph_1.png'), isTrue);
      expect(parsed.entries.containsKey('videos/pv_1.mov'), isTrue);

      // 穿越 → 拒收；白名单外扩展（exe）→ 拒收
      final traversal = pack({
        'manifest.json': manifest,
        'guide.json': guide,
        'photos/../evil.jpg': utf8.encode('x'),
      });
      expect(ShareService.parseShare(traversal), isNull);
      final badExt = pack({
        'manifest.json': manifest,
        'guide.json': guide,
        'photos/ph_1.exe': utf8.encode('x'),
      });
      expect(ShareService.parseShare(badExt), isNull);
      final badVidExt = pack({
        'manifest.json': manifest,
        'guide.json': guide,
        'videos/pv_1.exe': utf8.encode('x'),
      });
      expect(ShareService.parseShare(badVidExt), isNull);
    });

    test('estimateOriginalBytes：等于原件合计 + 常数；剔除后按剩余条目计', () async {
      final storage = MemoryStorage();
      final png = _fakePng();
      storage.blobs['pics/photowall/p1.png'] = png;
      storage.blobs['pics/photowall/p2.png'] = png;
      final guide = SeedData.buildDemoGuide();
      final patched2 = _withPhotoFiles(guide, {
        guide.photos.first.id: 'pics/photowall/p1.png',
        guide.photos.last.id: 'pics/photowall/p2.png',
      });
      final service = ShareService(storage);
      final full = await service.estimateOriginalBytes(guide: patched2);
      final excluded = await service.estimateOriginalBytes(
          guide: patched2, excludeIds: {guide.photos.last.id});
      // png 字节相同：估算差恰为 1 条照片 + 1 条缩略常数
      expect(full - excluded, png.length + 24 * 1024);
      expect(excluded, greaterThan(png.length));
    });

    test('账本归属照片注入（extraPhotos）：进 guide.json 与照片条目，接收端照常重映射',
        () async {
          final storage = MemoryStorage();
          final png = _fakePng();
          final albumRel = 'pics/photowall/p_album.jpg';
          storage.blobs[albumRel] = png;
          storage.blobs['pics/photowall/t_album.jpg'] = png;
          final extra = PhotoItem(
            id: 'wp_album1',
            takenAt: _fixedDate,
            file: albumRel,
            thumb: 'pics/photowall/t_album.jpg',
            name: '相册归属照片',
          );
          final guide = SeedData.buildDemoGuide();
          expect(guide.photos.where((p) => p.file == albumRel), isEmpty);

          final service = ShareService(storage);
          // —— 原片模式 ——
          final orig = await service.build(
            guide: guide,
            includePhotos: true,
            watermarkText: '',
            policy: ShareExportPolicy.original,
            extraPhotos: [extra],
          );
          final zip = await readOriginalZip(orig!);
          expect(zip.containsKey('photos/wp_album1.jpg'), isTrue);
          final gJson = jsonDecode(utf8.decode(zip['guide.json']!)) as Map;
          final photoIds = [
            for (final p in (gJson['photos'] as List)) p['id'],
          ];
          expect(photoIds, contains('wp_album1'));
          // 幂等：重复传入不产生重复条目
          final dual = await service.build(
            guide: guide,
            includePhotos: true,
            watermarkText: '',
            policy: ShareExportPolicy.original,
            extraPhotos: [extra, extra],
          );
          final zip2 = await readOriginalZip(dual!);
          final gJson2 = jsonDecode(utf8.decode(zip2['guide.json']!)) as Map;
          final ids2 = [
            for (final p in (gJson2['photos'] as List)) p['id'],
          ];
          expect(ids2.where((id) => id == 'wp_album1').length, 1);

          // —— 导入链：接收端把账本照片当作攻略照片重映射落盘 ——
          final parsed = ShareService.parseShare(zipBytes(zip))!;
          final applied = (await service.applyImport(parsed))!.guide;
          final importedExtra = [
            for (final p in applied.photos) if (p.file.contains('shared/')) p,
          ];
          expect(importedExtra.length, 1);
          expect(storage.blobs.containsKey(importedExtra.first.file), isTrue);
          expect(listEquals(storage.blobs[importedExtra.first.file], png), isTrue);

          // —— 水印模式同样注入（副本 + 缩略条目）——
          final wm = await service.build(
            guide: guide,
            includePhotos: true,
            watermarkText: '',
            extraPhotos: [extra],
          );
          final wmZip = _unzip(wm!.bytes);
          expect(wmZip.containsKey('photos/wp_album1.jpg'), isTrue);
          expect(wmZip.containsKey('thumbs/wp_album1.jpg'), isTrue);
        });

    test('Guide.sharedOriginal round-trip（缺键默认 false / true 正常往返）', () {      final base = SeedData.buildDemoGuide();
      expect(base.sharedOriginal, isFalse);
      final j = base.copyWith(sharedOriginal: true).toJson();
      expect(j['sharedOriginal'], true);
      final parsed = Guide.fromJson(jsonDecode(jsonEncode(base.toJson())));
      expect(parsed.sharedOriginal, isFalse);
      final withOriginal = Guide.fromJson(jsonDecode(jsonEncode({
        ...base.toJson().cast<String, dynamic>(),
        'shared': true,
        'sharedOriginal': true,
      })));
      expect(withOriginal.shared, isTrue);
      expect(withOriginal.sharedOriginal, isTrue);
    });
  });
}

/// 视频测试用的固定拍摄时间占位（避免逐处构造 DateTime）
final DateTime _fixedDate = DateTime(2026, 1, 1);

/// 给演示攻略中的指定照片补上 file/thumb 路径（copyWith 重建列表）
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

/// 把解包后的条目复原为 ZIP 字节（parseShare 输入用）
Uint8List zipBytes(Map<String, Uint8List> entriesMap) {
  final ar.Archive a = ar.Archive();
  for (final e in entriesMap.entries) {
    a.addFile(ar.ArchiveFile.bytes(e.key, e.value));
  }
  return Uint8List.fromList(ar.ZipEncoder().encode(a));
}
