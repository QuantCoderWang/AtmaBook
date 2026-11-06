import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 服务层取词通道：没有 BuildContext 的地方
/// （share_service / video_import_service / guide_notes_service / 水印等）
/// 直接用 `I18nService.t.xxx` 取文案。
///
/// 当前实例由 app.dart 的 `localeResolutionCallback` 同步过来，
/// 和 UI 通道 `AppLocalizations.of(context)` 用同一个 Locale；
/// 没初始化时回退中文模板。
class I18nService {
  I18nService._();

  static AppLocalizations? _current;

  static AppLocalizations get t =>
      _current ?? lookupAppLocalizations(const Locale('zh'));

  /// 由 app.dart / 测试显式同步当前语言
  static void update(Locale locale) {
    _current = lookupAppLocalizations(locale);
  }
}
