import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/pdv/sync_status/presentation/providers/sync_status_providers.dart';
import '../core/ui/theme/app_theme.dart';
import '../core/ui/theme/theme_mode_controller.dart';
import 'app_router.dart';

class TatuzinApp extends ConsumerWidget {
  const TatuzinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncHeartbeatProvider);
    final themeMode = ref.watch(appThemeModePreferenceProvider).themeMode;

    return MaterialApp.router(
      title: 'Tatuzin 2.0',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 240),
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
