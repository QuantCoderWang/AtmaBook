import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'storage_adapter.dart';
import 'write_queue.dart';

/// 应用数据根目录：`<系统应用支持目录>/tourguider`
///
/// 目录骨架：
/// ```
/// tourguider/
/// ├── guides/<guideId>.json
/// ├── guides_index.json
/// ├── pics/<guideId>/...  | pics/covers/... | pics/photowall/...
/// └── tiles/<packId>/{z}/{x}/{y}.png + pack.json
/// ```
class PlatformStorage extends StorageAdapter {
  PlatformStorage._(this._root);

  final String _root;

  File _fileOf(String rel) => File(joinRel(rel));

  String joinRel(String rel) {
    final parts = rel.split('/');
    return [_root, ...parts].join(Platform.pathSeparator);
  }

  Directory _dirOf(String rel) => Directory(joinRel(rel));

  @override
  String get locationLabel => _root;

  @override
  String absolutePath(String rel) => joinRel(rel);

  @override
  Future<bool> exists(String rel) async => _fileOf(rel).exists();

  @override
  Future<String> readText(String rel) async =>
      _fileOf(rel).readAsString();

  @override
  Future<void> writeText(String rel, String content) =>
      WriteQueue.instance.enqueue(() async {
        final f = _fileOf(rel);
        await f.parent.create(recursive: true);
        await _atomicReplace(f, (tmp) => tmp.writeAsString(content,
            flush: true));
      });

  @override
  Future<void> deleteFile(String rel) => WriteQueue.instance.enqueue(() async {
        final f = _fileOf(rel);
        if (await f.exists()) await f.delete();
      });

  @override
  Future<List<String>> listFiles(String dirRel) async {
    final d = _dirOf(dirRel);
    if (!await d.exists()) return [];
    final out = <String>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) {
        final full = e.path;
        final prefix = [_root, dirRel].join(Platform.pathSeparator);
        final tail = full.startsWith(prefix + Platform.pathSeparator)
            ? full.substring(prefix.length + 1)
            : full;
        out.add('$dirRel/$tail'.replaceAll('\\', '/'));
      }
    }
    return out;
  }

  @override
  Future<Uint8List?> readBytes(String rel) async {
    final f = _fileOf(rel);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> writeBytes(String rel, Uint8List bytes) =>
      WriteQueue.instance.enqueue(() async {
        final f = _fileOf(rel);
        await f.parent.create(recursive: true);
        await _atomicReplace(f, (tmp) => tmp.writeAsBytes(bytes, flush: true));
      });

  /// 原子替换：先写同目录临时文件，再改名顶掉目标。
  /// 任何时刻磁盘上的目标文件要么是旧的完整内容、要么是新的完整内容，
  /// 不再可能出现「两段内容拼接」的中间态。
  static Future<void> _atomicReplace(
      File target, Future<void> Function(File tmp) writeTmp) async {
    final tmp = File('${target.path}.tmp');
    await writeTmp(tmp);
    try {
      if (await target.exists()) await target.delete();
    } catch (_) {}
    try {
      await tmp.rename(target.path);
    } catch (_) {
      // 改名失败（偶发占用）退回复制；队列串行下依旧不会交错
      await tmp.copy(target.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteDir(String dirRel) async {
    final d = _dirOf(dirRel);
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// 工厂：初始化目录骨架后返回桌面存储实现
Future<StorageAdapter> createStorage() async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(
      [support.path, 'tourguider'].join(Platform.pathSeparator));
  for (final sub in ['guides', 'pics', 'tiles']) {
    Directory([root.path, sub].join(Platform.pathSeparator))
        .createSync(recursive: true);
  }
  return PlatformStorage._(root.path);
}
