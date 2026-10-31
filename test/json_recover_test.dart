import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:atma_book/core/io/storage_adapter.dart';
import 'package:atma_book/core/utils/json_recover.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/map_source.dart';
import 'package:atma_book/data/repos/guide_repository.dart';
import 'package:atma_book/data/seed_data.dart';

/// 内存版存储适配（与 data_layer_test 同款，专测损坏自愈）
class MemoryStorage extends StorageAdapter {
  final Map<String, String> texts = {};

  @override
  String get locationLabel => 'memory';

  @override
  Future<bool> exists(String rel) async => texts.containsKey(rel);

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
  Future<void> deleteFile(String rel) async => texts.remove(rel);

  @override
  Future<List<String>> listFiles(String dirRel) async => [
        for (final k in texts.keys)
          if (k.startsWith('$dirRel/')) k,
      ];

  @override
  Future<Uint8List?> readBytes(String rel) async => null;

  @override
  Future<void> writeBytes(String rel, Uint8List bytes) async {}

  @override
  Future<void> deleteDir(String dirRel) async {
    texts.removeWhere((k, _) => k.startsWith('$dirRel/'));
  }
}

Guide _demo() => SeedData.buildDemoGuide();

void main() {
  group('JSON 损坏自愈（并发写交错事故的防线）', () {
    test('extractFirstJsonDocument：两段拼接 → 抢救出首段', () {
      final doc1 = jsonEncode({'a': 1, 'b': '文本"}含括号}{', 'c': [1, 2]});
      final garbage = '{"ers":["mk_x"],"center":[30.0,120.0],"radius":100';
      final recovered = extractFirstJsonDocument('$doc1$garbage');
      expect(recovered, isNotNull);
      final parsed = jsonDecode(recovered!) as Map;
      expect(parsed['a'], 1);
      expect(parsed['b'], '文本"}含括号}{');
    });

    test('extractFirstJsonDocument：完整文档原样通过；截断/空/非 JSON → null', () {
      final doc = jsonEncode({'k': 'v'});
      expect(extractFirstJsonDocument(doc), doc);
      expect(extractFirstJsonDocument('{"k": "v"'), isNull); // 未闭合
      expect(extractFirstJsonDocument(''), isNull);
      expect(extractFirstJsonDocument('hello'), isNull);
    });

    test('GuideRepository.loadAll：损坏档自动恢复为干净档并留 .bad 备份', () async {
      final storage = MemoryStorage();
      final repo = GuideRepository(storage);
      final demo = _demo();
      final goodJson = jsonEncode(demo.toJson());

      // 模拟事故现场：完整文档 + 另一次写的残缺尾巴（同一文件交错）
      storage.texts['guides/${demo.id}.json'] =
          '$goodJson"ers":["mk_x"],"center":[30.0,120.0]';

      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.first.id, demo.id);
      // 恢复后重写为干净档；原坏档已备份
      expect(storage.texts['guides/${demo.id}.json'], goodJson);
      expect(storage.texts['guides/${demo.id}.json.bad'], isNotNull);
    });

    test('GuideRepository.loadAll：无法抢救的档跳过，不阻塞其余攻略', () async {
      final storage = MemoryStorage();
      final repo = GuideRepository(storage);
      final demo = _demo();

      // 截断档（无法抢救）+ 正常档
      storage.texts['guides/gd_broken.json'] = '{"id":"gd_broken","title":"断';
      storage.texts['guides/${demo.id}.json'] = jsonEncode(demo.toJson());

      final loaded = await repo.loadAll();
      expect(loaded.map((g) => g.id), [demo.id]);
    });

    test('ClusterZone 旧版含 route 键的 JSON 照常读取（字段已废弃）', () {
      final z = ClusterZone.fromJson({
        'id': 'zn_l',
        'label': '旧',
        'color': 0xFF123456,
        'members': ['m1'],
        'route': [
          [30.0, 120.0],
        ],
        'road': false,
        'center': [30.0, 120.0],
        'radiusMeters': 1500,
      });
      expect(z.center, const LatLng(30, 120));
      expect(z.radiusMeters, 1500);
    });

    test('MapSources.forRegion 仍可用（仓库回归）', () {
      expect(MapSources.forRegion(GuideRegion.china).id, isNotEmpty);
    });
  });
}
