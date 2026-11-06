/// 原片包流式打包用的临时文件工具（条件导入）。
/// 桌面/移动在系统临时目录建工作目录；Web 没有文件系统，桩实现直接抛错。
library;

export 'share_temp_stub.dart'
    if (dart.library.io) 'share_temp_io.dart';
