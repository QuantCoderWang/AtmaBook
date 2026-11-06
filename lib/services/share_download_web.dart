// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import '../core/i18n_service.dart';

/// dart:html 实现：Blob + 临时 URL + anchor 触发浏览器下载，
/// 和平时下载文件一样，落到浏览器下载目录。
Future<String> saveShareFile(String filename, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/zip');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
  return I18nService.t.webDownloadDone(filename);
}

/// 原片模式产物搬移：Web 不支持，入口已在上层禁用。
Future<String> saveShareFileAt(String filename, String tempPath) async {
  throw UnsupportedError('原片打包模式不支持 Web（无文件系统）');
}
