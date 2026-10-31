import 'dart:typed_data';

/// 兜底桩：既无 dart:io 也无 dart:html 的环境下不可用（当前不存在此目标）。
Future<String> saveShareFile(String filename, Uint8List bytes) async {
  throw UnsupportedError('当前平台不支持分享文件输出：$filename');
}

/// 原片模式流式产物搬移（兜底桩；原片模式仅桌面/移动可用）。
Future<String> saveShareFileAt(String filename, String tempPath) async {
  throw UnsupportedError('当前平台不支持分享文件输出：$filename');
}
