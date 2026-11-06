/// 平台分享文件输出（条件导入）。
/// 桌面写入「下载」目录（失败回退文档目录）；Web 用 Blob + anchor 触发下载。
/// `saveShareFileAt` 把原片临时文件搬到输出位置，搬完即删。
library;

export 'share_download_stub.dart'
    if (dart.library.html) 'share_download_web.dart'
    if (dart.library.io) 'share_download_io.dart';
