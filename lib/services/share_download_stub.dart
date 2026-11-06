import 'dart:typed_data';

/// 兜底桩：既没有 dart:io 也没有 dart:html 时走这里（目前没有这种目标）。
Future<String> saveShareFile(String filename, Uint8List bytes) async {
  throw UnsupportedError('当前平台不支持分享文件输出：$filename');
}

/// 原片模式产物搬移（兜底桩；原片模式只在桌面/移动能用）。
Future<String> saveShareFileAt(String filename, String tempPath) async {
  throw UnsupportedError('当前平台不支持分享文件输出：$filename');
}
