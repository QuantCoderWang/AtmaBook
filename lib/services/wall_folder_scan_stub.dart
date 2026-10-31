import '../core/i18n_service.dart';
import 'wall_scan_types.dart';

/// 浏览器桩实现：无法访问任意目录，引导改用手动导入
Future<WallFolderCandidates> readFolderPhotoCandidates(
  String dirPath, {
  required int limit,
}) async =>
    WallFolderCandidates(note: I18nService.t.webScanUnsupported);
