import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../core/io/storage_adapter.dart';
import '../data/models/guide.dart';
import '../data/models/map_source.dart';
import 'media_store.dart';

/// 离线瓦片 Provider：
/// - 构造时扫描 `tiles/<packId>/` 已获取瓦片 → `getImage` 内本地命中优先；
/// - 缺失瓦片：在线模式回退网络请求（与所选包相同源），纯离线显示灰块；
/// - 本地瓦片 ImageProvider 按 rel 路径复用实例 → 命中 Flutter ImageCache，
///   同一瓦片不重复解码；
/// - 支持多包按顺序命中（先选中的一个为主，可传多个做兜底）。
class OfflineTileProvider extends TileProvider {
  OfflineTileProvider._({
    required this.packs,
    required this.available,
    required this.onlineFallback,
    required this.greyTile,
  });

  final List<TilePack> packs;

  /// packId → 已获取的相对路径集合（`tiles/<id>/<z>/<x>/<y>.<ext>`）
  final Map<String, Set<String>> available;
  final bool onlineFallback;
  final Uint8List greyTile;

  /// 扫描目录 → 构建实例（页面切换源时 await 一次即可）
  static Future<OfflineTileProvider> load(
    List<TilePack> packs, {
    required bool onlineFallback,
  }) async {
    final map = <String, Set<String>>{};
    for (final p in packs) {
      final files = await activeStorage.listFiles('tiles/${p.id}');
      map[p.id] = files.toSet();
    }
    return OfflineTileProvider._(
      packs: packs,
      available: map,
      onlineFallback: onlineFallback,
      greyTile: await greyTileBytes(),
    );
  }

  /// 灰块占位（256×256 PNG，惰性生成并缓存）
  static Uint8List? _greyCache;
  static Future<Uint8List> greyTileBytes() async {
    final c = _greyCache;
    if (c != null) return c;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, 256, 256),
        Paint()..color = const Color(0xFFE4E0D8));
    final picture = recorder.endRecording();
    final img = await picture.toImage(256, 256);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    _greyCache = bytes;
    return bytes;
  }

  Uint8List get _grey => greyTile;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // 1) 本地命中优先（多包按序）
    for (final p in packs) {
      final keys = available[p.id];
      if (keys == null) continue;
      final rel =
          'tiles/${p.id}/${coordinates.z}/${coordinates.x}/${coordinates.y}.${p.ext}';
      if (keys.contains(rel)) {
        return _LocalTileImage.of(rel);
      }
    }
    // 2) 缺失 → 网络回退（同源在线请求）
    if (onlineFallback && packs.isNotEmpty) {
      final p = packs.first;
      final s = MapSources.byId(p.sourceId);
      if (s != null) return NetworkImage(_buildUrl(s, coordinates));
    }
    // 3) 纯离线 → 灰块
    return MemoryImage(_grey, scale: 1.0);
  }

  String _buildUrl(MapSource s, TileCoordinates c) {
    var url = s.urlTemplate;
    if (s.subdomains.isNotEmpty) {
      final sub = s.subdomains[(c.x * 31 + c.y) % s.subdomains.length];
      url = url.replaceFirst('{s}', sub);
    }
    return url
        .replaceFirst('{z}', '${c.z}')
        .replaceFirst('{x}', '${c.x}')
        .replaceFirst('{y}', '${c.y}')
        .replaceFirst('{key}', ''); // tk 在离线包场景不参与（在线天地图走在线源）
  }
}

/// 本地文件瓦片的 ImageProvider：按 rel 复用单例 → ImageCache 防重复解码
class _LocalTileImage extends ImageProvider<_LocalTileImage> {
  _LocalTileImage._(this.rel);

  final String rel;

  static final Map<String, _LocalTileImage> _instances = {};

  factory _LocalTileImage.of(String rel) =>
      _instances.putIfAbsent(rel, () => _LocalTileImage._(rel));

  @override
  Future<_LocalTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_LocalTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _LocalTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadCodec(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadCodec(
    _LocalTileImage key,
    ImageDecoderCallback decode,
  ) async {
    var bytes = MediaStore.cacheBytes(key.rel);
    bytes ??= await activeStorage.readBytes(key.rel);
    if (bytes == null) {
      // 扫描后文件又被删除的极端情况：给出可辨识的失败（TileLayer 显示成灰块/占位）
      throw StateError('离线瓦片缺失：${key.rel}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) => other is _LocalTileImage && other.rel == rel;

  @override
  int get hashCode => rel.hashCode;
}
