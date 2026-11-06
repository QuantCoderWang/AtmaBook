import '../core/i18n_service.dart';
import 'wall_scan_types.dart';

/// 浏览器桩：读不了任意目录，引导改手动导入
Future<WallFolderCandidates> readFolderPhotoCandidates(
  String dirPath, {
  required int limit,
}) async =>
    WallFolderCandidates(note: I18nService.t.webScanUnsupported);
