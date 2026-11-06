import 'dart:typed_data';

import 'storage_local.dart'
    if (dart.library.html) 'storage_web.dart' as impl;

/// 存储适配层：
/// - 桌面（Windows）：`path_provider` 应用支持目录下 `tourguider/` 的真实文件 IO；
/// - Web（Edge 预览）：无文件系统，JSON 降级存 `shared_preferences`，
///   媒体字节降级为「小文件 base64 偏好设置 / 大文件仅会话内存」。
///
/// 统一用 `tourguider/` 下的相对路径寻址，例如：
///   `guides/<guideId>.json`、`guides_index.json`、
///   `pics/<guideId>/cover.jpg`、`pics/covers/<guideId>.bin`（Web）
///   `tiles/<packId>/{z}/{x}/{y}.png`、`tiles/<packId>/pack.json`
abstract class StorageAdapter {
  /// 数据根目录的可读描述（设置页/诊断展示）
  String get locationLabel;

  Future<bool> exists(String rel);

  Future<String> readText(String rel);

  Future<void> writeText(String rel, String content);

  Future<void> deleteFile(String rel);

  /// 列出 `dirRel` 下（含子目录）的文件相对路径，不存在返回空
  Future<List<String>> listFiles(String dirRel);

  Future<Uint8List?> readBytes(String rel);

  /// 字节写入：桌面=落盘；Web=≤1MB 转 base64 持久化，更大则仅会话内存
  Future<void> writeBytes(String rel, Uint8List bytes);

  /// 递归删除目录（REL 路径），不存在时静默
  Future<void> deleteDir(String dirRel);

  /// 相对路径 → 绝对文件系统路径（视频播放 / ffmpeg 等外部进程需要真实路径；
  /// Web 无文件系统 → 默认抛 UnsupportedError，桌面端覆写）。
  String absolutePath(String rel) =>
      throw UnsupportedError('该平台不支持文件系统路径');

  /// 列出目录下所有 `*.json` 文件（不含子目录中的其他扩展名）
  Future<List<String>> listJsonFiles(String dirRel) async {
    final all = await listFiles(dirRel);
    return all.where((f) => f.endsWith('.json')).toList();
  }
}

/// 启动时构建平台存储：桌面端会顺带初始化 `tourguider/` 子目录骨架，
/// 并记录为进程级活动实例（仓库/服务直接取 `activeStorage`）。
StorageAdapter? _activeInstance;

StorageAdapter get activeStorage {
  final s = _activeInstance;
  if (s == null) {
    throw StateError('存储尚未初始化（initStorage 未调用）');
  }
  return s;
}

Future<StorageAdapter> initStorage() async {
  final s = await impl.createStorage();
  _activeInstance = s; // 无论桌面/Web 都登记，后续 activeStorage 读写可靠
  return s;
}

