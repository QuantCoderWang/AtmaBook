import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:atma_book/core/io/storage_adapter.dart';
import 'package:atma_book/core/utils/ids.dart';
import 'package:atma_book/data/models/guide.dart';
import 'package:atma_book/data/models/map_source.dart';
import 'package:atma_book/data/repos/guide_repository.dart';
import 'package:atma_book/data/seed_data.dart';
import 'package:atma_book/state/guide_editor.dart';
import 'package:atma_book/state/guides_provider.dart';

/// 内存版存储适配（单测专用，不落盘）
class MemoryStorage extends StorageAdapter {
  final Map<String, String> texts = {};
  final Map<String, Uint8List> blobs = {};
  final Map<String, Set<String>> dirs = {};

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
    final p = rel.lastIndexOf('/');
    if (p > 0) {
      dirs.putIfAbsent(rel.substring(0, p), () => {}).add(rel);
    }
  }

  @override
  Future<void> deleteFile(String rel) async {
    texts.remove(rel);
    blobs.remove(rel);
  }

  @override
  Future<List<String>> listFiles(String dirRel) async {
    final out = <String>[];
    texts.forEach((k, _) {
      if (k.startsWith('$dirRel/')) out.add(k);
    });
    blobs.forEach((k, _) {
      if (k.startsWith('$dirRel/')) out.add(k);
    });
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

void main() {
  group('M2 数据层', () {
    test('攻略 JSON round-trip：字段保真', () {
      final guide = SeedData.buildDemoGuide();
      final json = guide.toJson();
      final restored = Guide.fromJson(json);
      expect(restored.id, guide.id);
      expect(restored.title, guide.title);
      expect(restored.summary, guide.summary);
      expect(restored.sourceId, guide.sourceId);
      expect(restored.markers.length, guide.markers.length);
      expect(restored.photos.length, guide.photos.length);
      expect(restored.clusters.length, guide.clusters.length);
      expect(restored.coverImage, guide.coverImage);
      if (guide.markers.isNotEmpty) {
        expect(restored.markers.first.id, guide.markers.first.id);
        expect(restored.markers.first.title, guide.markers.first.title);
        expect(restored.markers.first.links.length,
            guide.markers.first.links.length);
      }
    });

    test('仓库：create→save→delete 落盘与恢复', () async {
      final storage = MemoryStorage();
      final repo = GuideRepository(storage);
      final before = await repo.loadAll();
      expect(before, isNotEmpty);

      final provider = GuidesProvider(
          repository: repo, guides: [...before]);
      final g = await provider.create(
          title: '单元测试攻略', summary: 'S', region: GuideRegion.overseas);
      expect(g.sourceId, MapSources.osm.id);
      expect(storage.texts['guides/${g.id}.json'], isNotNull);

      // 从存储重新加载应包含新攻略
      final reloaded = await repo.loadAll();
      expect(reloaded.any((e) => e.id == g.id), isTrue);

      await provider.remove(g.id);
      expect(await storage.exists('guides/${g.id}.json'), isFalse);
      final after = await GuideRepository(storage).loadAll();
      expect(after.any((e) => e.id == g.id), isFalse);
    });

    test('封面：setCoverBytes 持久化并加载', () async {
      final storage = MemoryStorage();
      final repo = GuideRepository(storage);
      final guides = await repo.loadAll();
      final provider = GuidesProvider(repository: repo, guides: guides);
      final g = guides.first;
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      await provider.setCoverBytes(g.id, bytes);
      final updated = provider.byId(g.id)!;
      expect(updated.coverImage, isNotNull);
      expect(storage.texts.containsKey('guides/${updated.id}.json'), isTrue);
      final covers = await repo.loadCovers([updated]);
      expect(covers[g.id], isNotNull);

      await provider.setCoverBytes(g.id, null); // 移除封面
      final removed = provider.byId(g.id)!;
      expect(removed.coverImage, isNull);
    });
  });

  group('M3 标记增删改（GuideEditor 仓库联动）', () {
    Future<(GuidesProvider, GuideEditor)> makeEditor() async {
      final storage = MemoryStorage();
      final repo = GuideRepository(storage);
      final guides = await repo.loadAll();
      final provider = GuidesProvider(repository: repo, guides: guides);
      final g = await provider.create(
          title: 'M3 测试', summary: '', region: GuideRegion.china);
      final editor = GuideEditor(g, guides: provider);
      return (provider, editor);
    }

    test('添加/编辑/删除标记并持久化', () async {
      final (provider, ed) = await makeEditor();
      var place = Place(
        id: newId('mk'),
        title: '断桥残雪',
        categoryId: 'scenic',
        lat: 30.2592,
        lng: 120.1495,
        mustVisit: true,
      );
      ed.addPlace(place);
      expect(ed.guide.markers.length, provider.byId(ed.guide.id)!.markers.length);

      place = place.copyWith(
          title: '断桥残雪（meta 精修）', description: '清晨人少', colorValue: 0xFFE53935);
      ed.updatePlace(place);
      final updated = provider.byId(ed.guide.id)!;
      expect(updated.updatedAt.isAfter(updated.createdAt), isTrue);
      expect(
          updated.markers
              .firstWhere((m) => m.id == place.id)
              .description,
          '清晨人少');

      ed.removePlace(place.id);
      final removed = provider.byId(ed.guide.id)!;
      expect(removed.markers.any((m) => m.id == place.id), isFalse);
    });

    test('必去切换与 zoneOf / initialCenter 帮手', () async {
      final (provider, ed) = await makeEditor();
      final p = Place(
        id: newId('mk'),
        title: '白堤',
        categoryId: 'scenic',
        lat: 30.2566,
        lng: 120.1476,
      );
      ed.addPlace(p);
      expect(ed.byPlaceId(p.id)!.mustVisit, isFalse);
      ed.toggleMustVisit(p.id);
      expect(provider.byId(ed.guide.id)!.markers.first.mustVisit, isTrue);
      expect(ed.initialCenter.latitude, closeTo(30.2566, 1e-4));
      final zone = ed.zoneOf(p);
      expect(zone, isNull); // M4 之前与无演示簇时为空
      expect(LatLng(p.lat, p.lng), const LatLng(30.2566, 120.1476));
    });
  });
}
