import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atma_book/core/i18n_service.dart';
import 'package:atma_book/l10n/app_localizations.dart';
import 'package:atma_book/state/settings_provider.dart';

/// 国际化 P0 基建测试：
/// 语言偏好持久化 / locale 折算回退 / 服务层取词通道与 UI 同源。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('语言偏好 round-trip：持久化值可恢复；无存储时默认中文', () async {
    SharedPreferences.setMockInitialValues({'tg.language': 'en'});
    final s = await AppSettings.load();
    expect(s.language, AppLanguage.en);

    SharedPreferences.setMockInitialValues({});
    final s2 = await AppSettings.load();
    expect(s2.language, AppLanguage.zh, reason: '默认中文（项目口径）');
  });

  test('locale 折算：显式选项优先；跟随系统非中英回退中文', () {
    final s = AppSettings();

    s.language = AppLanguage.en;
    expect(s.explicitLocale, const Locale('en'));
    expect(s.resolveUiLocale(const Locale('ja')), const Locale('en'),
        reason: '显式英文优先，与系统语言无关');

    s.language = AppLanguage.zh;
    expect(s.resolveUiLocale(const Locale('en')), const Locale('zh'));

    s.language = AppLanguage.system;
    expect(s.explicitLocale, isNull, reason: '跟随系统交给 localeResolutionCallback');
    expect(s.resolveUiLocale(const Locale('en', 'US')), const Locale('en'));
    expect(s.resolveUiLocale(const Locale('zh', 'CN')), const Locale('zh'));
    expect(s.resolveUiLocale(const Locale('ja')), const Locale('zh'),
        reason: '非中英系统语言回退中文');
    expect(s.resolveUiLocale(null), const Locale('zh'));
  });

  test('服务层取词通道：默认中文 / update 即切换 / 与 UI 同源', () {
    // 未同步时（纯 Dart 场景）回退中文模板
    expect(I18nService.t.navTitleSettings, '设置');

    I18nService.update(const Locale('en'));
    expect(I18nService.t.navTitleSettings, 'Settings');

    I18nService.update(const Locale('zh'));
    expect(I18nService.t.navTitleSettings, '设置');
    expect(I18nService.t.navTitleSettings,
        lookupAppLocalizations(const Locale('zh')).navTitleSettings,
        reason: '服务层通道与 UI 通道同源同文');
  });
}
