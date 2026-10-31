/// 平台分享文件输出（条件导入桩）：
/// - 桌面（dart:io）：写入「下载」目录（失败回退文档目录），返回完整路径；
/// - Web（dart:html）：Blob + anchor 触发浏览器下载，返回提示文案。
/// - 新增 `saveShareFileAt`：原片模式流式产物（临时文件）搬移至输出位置，
///   搬移完成即删除临时文件（桌面实现；Web/桩位兜底抛错——原片模式不开放 Web）。
///
/// 实现在同目录 share_download_io / share_download_web，由条件导入选择。
library;

export 'share_download_stub.dart'
    if (dart.library.html) 'share_download_web.dart'
    if (dart.library.io) 'share_download_io.dart';
