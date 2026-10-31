import 'dart:io';

/// 在系统临时目录创建一次性工作目录（`<prefix>_<毫秒戳>`，唯一随机后缀），
/// 返回绝对路径。目录内即可用相对文件名产出临时 ZIP，最终由调用方删除目录
/// （不留残留）。刻意用 `Directory.systemTemp` 而非 path_provider：
/// 无插件通道依赖——flutter_test 单测环境（binding 未初始化、无 mock 通道）
/// 与 Async isolate 内同样可用。
Future<String> createTempWorkDir(String prefix) async {
  final dir = await Directory.systemTemp.createTemp('tgshare_$prefix');
  return dir.path;
}

/// 递归删除临时工作目录；失败静默（系统临时目录清理兜底）。
Future<void> deleteTempWorkDir(String dirPath) async {
  try {
    await Directory(dirPath).delete(recursive: true);
  } catch (_) {}
}

/// 绝对路径文件的字节尺寸；不存在/不可读抛异常由调用方处理。
Future<int> fileSizeBytes(String absPath) async => File(absPath).length();
