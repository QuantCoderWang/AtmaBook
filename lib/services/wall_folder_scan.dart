import 'wall_scan_types.dart';
import 'wall_folder_scan_stub.dart'
    if (dart.library.io) 'wall_folder_scan_io.dart' as impl;

export 'wall_scan_types.dart';

/// 目录照片读取入口：桌面 = dart:io 实现；Web = 桩（提示不支持）
Future<WallFolderCandidates> readFolderPhotoCandidates(
  String dirPath, {
  required int limit,
}) =>
    impl.readFolderPhotoCandidates(dirPath, limit: limit);
