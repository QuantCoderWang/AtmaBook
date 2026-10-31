import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../i18n_service.dart';
import 'storage_adapter.dart';

/// Web（Edge 预览）降级实现：
/// - JSON 文本 → `shared_preferences` 键 `tg.file.<rel>`；
/// - 字节 → ≤ 1MB 的存 base64 键 `tg.blob.<rel>`（封面可跨会话保留），
///   更大的（照片原图等）仅存会话内存，页面刷新即失。
class PlatformStorage extends StorageAdapter {
  PlatformStorage._(this._prefs) {
    _instance = _prefs;
  }

  late final SharedPreferences _prefs;
  static SharedPreferences? _instance;

  static const _maxPersistentBlobBytes = 1 << 20; // 1MB

  final Map<String, Uint8List> _memoryBlobs = {};

  String _textKey(String rel) => 'tg.file.$rel';

  String _blobKey(String rel) => 'tg.blob.$rel';

  @override
  String get locationLabel => I18nService.t.webStorageLabel;

  @override
  Future<bool> exists(String rel) async {
    final p = _instance;
    if (p == null) return false;
    return p.containsKey(_textKey(rel)) ||
        p.containsKey(_blobKey(rel)) ||
        _memoryBlobs.containsKey(rel);
  }

  @override
  Future<String> readText(String rel) async {
    final p = _instance ??= _prefs;
    final v = p.getString(_textKey(rel));
    if (v == null) throw StateError('web storage missing: $rel');
    return v;
  }

  @override
  Future<void> writeText(String rel, String content) async =>
      (await _get()).setString(_textKey(rel), content);

  @override
  Future<void> deleteFile(String rel) async {
    final p = await _get();
    await p.remove(_textKey(rel));
    await p.remove(_blobKey(rel));
    _memoryBlobs.remove(rel);
  }

  @override
  Future<List<String>> listFiles(String dirRel) async {
    final p = await _get();
    final out = <String>{};
    final prefix = '$dirRel/';
    for (final key in p.getKeys()) {
      if (key.startsWith('tg.file.$prefix')) {
        out.add(key.substring('tg.file.'.length));
      } else if (key.startsWith('tg.blob.$prefix')) {
        out.add(key.substring('tg.blob.'.length));
      }
    }
    return out.toList();
  }

  @override
  Future<Uint8List?> readBytes(String rel) async {
    final mem = _memoryBlobs[rel];
    if (mem != null) return mem;
    final v = (await _get()).getString(_blobKey(rel));
    if (v == null) return null;
    return base64Decode(v);
  }

  @override
  Future<void> writeBytes(String rel, Uint8List bytes) async {
    _memoryBlobs[rel] = bytes;
    if (bytes.length > _maxPersistentBlobBytes) return;
    await (await _get())
        .setString(_blobKey(rel), base64Encode(bytes));
  }

  @override
  Future<void> deleteDir(String dirRel) async {
    final p = await _get();
    final prefix = 'tg.file.$dirRel/';
    final blobPrefix = 'tg.blob.$dirRel/';
    for (final key in p.getKeys().where((k) =>
        k.startsWith(prefix) || k.startsWith(blobPrefix))) {
      await p.remove(key);
    }
    _memoryBlobs.removeWhere((k, _) => k.startsWith('$dirRel/'));
  }

  Future<SharedPreferences> _get() async {
    return _instance ??= _prefs;
  }
}

Future<StorageAdapter> createStorage() async {
  return PlatformStorage._(await SharedPreferences.getInstance());
}
