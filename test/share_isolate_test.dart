import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as ar;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/map_source.dart' show GuideRegion;
import 'package:atma_book/services/share_service.dart';

/// 实证：与 UI 侧一致的 compute(T, bytes) 解包链路，在 VM/隔离环境是否可用。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List buildZip() {
    final guide = Guide(
      id: 'gd_test',
      title: '测试攻略',
      summary: '',
      region: GuideRegion.china,
      sourceId: 'amap_vector',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final manifest = jsonEncode({
      'format': 'tgshare',
      'formatVersion': 1,
      'fingerprint': '0' * 16,
      'sourceGuideId': 'gd_test',
      'exportedAt': '2026-10-21T00:00:00',
      'watermarkText': '',
      'includesPhotos': false,
      'counts': {'markers': 0, 'photos': 0, 'clusters': 0, 'images': 0},
    });
    final a = ar.Archive()
      ..addFile(ar.ArchiveFile.string('manifest.json', manifest))
      ..addFile(ar.ArchiveFile.string('guide.json', jsonEncode(guide.toJson())));
    return Uint8List.fromList(ar.ZipEncoder().encode(a));
  }

  test('isolate 内非 ZIP → null（函数可执行）', () async {
    final r = await compute(
        ShareService.parseShare,
        Uint8List.fromList(utf8.encode('hello')));
    expect(r, isNull);
  });

  test('isolate 内解析真实包 → 与同步解析结果一致', () async {
    final zip = buildZip();
    final sync = ShareService.parseShare(zip);
    final viaIsolate = await compute(ShareService.parseShare, zip);
    expect(sync, isNotNull);
    expect(viaIsolate, isNotNull);
    expect(viaIsolate!.manifest['format'], sync!.manifest['format']);
    expect(viaIsolate.guide.title, '测试攻略');
    expect(viaIsolate.guide.id, sync.guide.id);
  });
}
