/// 原片包流式打包的临时文件工具（条件导入桩）：
/// - 桌面/移动（dart:io）：在系统临时目录下创建工作目录，供 ZIP 流式写出，
///   绝对路径取文件尺寸；打包完成/失败后由调用方删除整个目录（不留残留副本）；
/// - Web：无文件系统，原片模式不可用——上层（分享弹窗）已禁用入口，此处兜底抛错。
///
/// 实现在同目录 share_temp_io / share_temp_stub，由条件导入选择。
library;

export 'share_temp_stub.dart'
    if (dart.library.io) 'share_temp_io.dart';
