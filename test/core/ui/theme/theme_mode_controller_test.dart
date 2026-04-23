import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tatuzin/core/database/app_database.dart';
import 'package:tatuzin/core/database/providers/database_providers.dart';
import 'package:tatuzin/core/logging/app_logger.dart';
import 'package:tatuzin/core/ui/theme/app_theme_mode.dart';
import 'package:tatuzin/core/ui/theme/theme_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeModePreference', () {
    test('falls back to system for unknown storage values', () {
      expect(
        AppThemeModePreference.fromStorageValue('unknown'),
        AppThemeModePreference.system,
      );
      expect(
        AppThemeModePreference.fromStorageValue(null),
        AppThemeModePreference.system,
      );
    });

    test('maps stored values back to enum entries', () {
      expect(
        AppThemeModePreference.fromStorageValue('light'),
        AppThemeModePreference.light,
      );
      expect(
        AppThemeModePreference.fromStorageValue('dark'),
        AppThemeModePreference.dark,
      );
    });
  });

  group('ThemeModeController', () {
    late AppDatabase database;
    late String databasePath;

    setUp(() async {
      databasePath = p.join(
        'C:/tatuzin 2.0/.dart_tool',
        'theme-mode-test-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      database = AppDatabase(
        logger: const AppLogger(),
        databasePathOverride: databasePath,
      );
      await database.initialize();
    });

    tearDown(() async {
      await database.close();
      final file = File(databasePath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('restores persisted theme mode from local app settings', () async {
      await database.saveAppSetting(
        key: AppThemeModePreference.settingKey,
        value: AppThemeModePreference.dark.storageValue,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      final restored = Completer<AppThemeModePreference>();
      container.listen<AppThemeModePreference>(
        appThemeModePreferenceProvider,
        (previous, next) {
          if (!restored.isCompleted &&
              next == AppThemeModePreference.dark) {
            restored.complete(next);
          }
        },
        fireImmediately: true,
      );

      expect(
        await restored.future.timeout(const Duration(seconds: 2)),
        AppThemeModePreference.dark,
      );
    });

    test('persists user theme selection to SQLite', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(appThemeModePreferenceProvider.notifier)
          .setPreference(AppThemeModePreference.light);

      expect(
        container.read(appThemeModePreferenceProvider),
        AppThemeModePreference.light,
      );
      expect(
        await database.loadAppSetting(AppThemeModePreference.settingKey),
        AppThemeModePreference.light.storageValue,
      );
    });
  });
}
