import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 桌面（dart:io）实现：写入「下载」目录，失败回退文档目录。
///
/// 返回完整路径供 SnackBar 展示。写新文件无需走队列
/// （不参与应用数据目录的并发写竞争）。
Future<String> saveShareFile(String filename, Uint8List bytes) async {
  final dir = await _outputDir();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// 原片模式流式产物：把临时 ZIP 文件搬移至输出位置。
/// 优先 rename（同分区零拷贝瞬时完成）；跨分区回退 copy；随后删除临时
/// 文件（其所在临时目录由调用方在完成回调中整体清理，此处双保险）。
Future<String> saveShareFileAt(String filename, String tempPath) async {
  final dir = await _outputDir();
  final target = File('${dir.path}${Platform.pathSeparator}$filename');
  final temp = File(tempPath);
  try {
    await temp.rename(target.path);
  } catch (_) {
    await temp.copy(target.path);
    try {
      await temp.delete();
    } catch (_) {}
  }
  return target.path;
}

Future<Directory> _outputDir() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}
