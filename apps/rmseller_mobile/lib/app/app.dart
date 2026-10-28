import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/app_settings_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root Widget for RMSeller Mobile Application.
class RMSellerApp extends ConsumerWidget {
  const RMSellerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'RMSeller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(settings.fontScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: AppRouter.router,
    );
  }
}
