import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// 服务层取词通道：无 BuildContext 的位置
/// （share_service / video_import_service / guide_notes_service / 水印 等）
/// 直接 `I18nService.t.xxx` 取词。
///
/// - 当前实例由 app.dart 的 `localeResolutionCallback` 统一同步
///   （与 UI 通道 `AppLocalizations.of(context)` 同一 Locale、同一来源）；
/// - 未初始化时回退中文模板。
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
