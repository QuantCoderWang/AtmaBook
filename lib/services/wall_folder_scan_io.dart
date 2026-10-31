import 'dart:io';
import 'dart:typed_data';

import '../core/i18n_service.dart';
import 'wall_scan_types.dart';

/// 桌面实现：递归当前目录 + 一层子目录，jpg/jpeg/png，
/// 按文件修改时间倒序（从新一页页）读至 limit 张为止。
/// 只读字节；EXIF 解析/落盘/归属由 WallPhotoService 统一执行。
Future<WallFolderCandidates> readFolderPhotoCandidates(
  String dirPath, {
  required int limit,
}) async {
  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return WallFolderCandidates(
          note: I18nService.t.dirNotFound(dirPath));
    }
    const exts = {'.jpg', '.jpeg', '.png'};
    final files = <File>[];
    for (final e in dir.listSync(followLinks: false)) {
      if (e is File) {
        if (_hasExt(e.path, exts)) files.add(e);
      } else if (e is Directory) {
        for (final f in e.listSync(followLinks: false)) {
          if (f is File && _hasExt(f.path, exts)) files.add(f);
        }
      }
    }
    if (files.isEmpty) {
      return WallFolderCandidates(note: I18nService.t.folderNoPhotos);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final payloads = <Uint8List>[];
    for (final f in files) {
      if (payloads.length >= limit) break;
      try {
        final bytes = await f.readAsBytes();
        if (bytes.isNotEmpty) payloads.add(bytes);
      } catch (_) {
        // 单张读取失败跳过
      }
    }
    if (payloads.isEmpty) {
      return WallFolderCandidates(note: I18nService.t.folderAllFailed);
    }
    return WallFolderCandidates(payloads: payloads);
  } catch (_) {
    return WallFolderCandidates(note: I18nService.t.folderReadFail);
  }
}

bool _hasExt(String path, Set<String> exts) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return exts.contains(path.substring(dot).toLowerCase());
}
