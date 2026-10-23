import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/preferences/app_settings_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root application widget configuring routing, themes, font scaling and preferences.
class RMBrokerApp extends ConsumerWidget {
  const RMBrokerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'RMBroker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      builder: (context, child) {
        Widget content = MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(settings.fontScale)),
          child: child ?? const SizedBox.shrink(),
        );

        if (settings.eyeProtectionMode) {
          content = Stack(
            textDirection: TextDirection.ltr,
            children: [
              content,
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x12FF9800), // ~7% comfortable warm tint without obscuring prices
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return content;
      },
      routerConfig: AppRouter.router,
    );
  }
}
