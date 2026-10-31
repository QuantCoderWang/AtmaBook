import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/i18n_service.dart';
import 'l10n/app_localizations.dart';
import 'core/theme.dart';
import 'state/settings_provider.dart';
import 'ui/home/home_page.dart';

class AtmaBookApp extends StatelessWidget {
  const AtmaBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 语言选项（i18n P0）
    return Consumer<AppSettings>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'AtmaBook',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: settings.explicitLocale,
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // UI 与服务层 I18nService 双通道同源
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            final resolved = settings.resolveUiLocale(deviceLocale);
            I18nService.update(resolved);
            return resolved;
          },
          home: const HomePage(),
        );
      },
    );
  }
}
