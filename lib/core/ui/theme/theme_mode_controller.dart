import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/providers/database_providers.dart';
import '../../logging/app_logger.dart';
import 'app_theme_mode.dart';

final appThemeModePreferenceProvider =
    NotifierProvider<ThemeModeController, AppThemeModePreference>(
      ThemeModeController.new,
    );

class ThemeModeController extends Notifier<AppThemeModePreference> {
  bool _hasUserSelection = false;

  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  AppThemeModePreference build() {
    unawaited(_restore());
    return AppThemeModePreference.system;
  }

  Future<void> _restore() async {
    try {
      final rawValue = await ref
          .read(appDatabaseProvider)
          .loadAppSetting(AppThemeModePreference.settingKey);
      if (_hasUserSelection) {
        return;
      }
      state = AppThemeModePreference.fromStorageValue(rawValue);
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Nao foi possivel restaurar a preferencia de tema do app.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> setPreference(AppThemeModePreference preference) async {
    final previous = state;
    _hasUserSelection = true;
    state = preference;

    try {
      await ref.read(appDatabaseProvider).saveAppSetting(
        key: AppThemeModePreference.settingKey,
        value: preference.storageValue,
      );
    } on Object catch (error, stackTrace) {
      state = previous;
      _logger.error(
        'Falha ao salvar a preferencia de tema do app.',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}
