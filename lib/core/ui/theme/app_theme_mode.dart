import 'package:flutter/material.dart';

enum AppThemeModePreference {
  system,
  light,
  dark;

  static const String settingKey = 'ui.theme_mode';

  ThemeMode get themeMode {
    return switch (this) {
      AppThemeModePreference.light => ThemeMode.light,
      AppThemeModePreference.dark => ThemeMode.dark,
      AppThemeModePreference.system => ThemeMode.system,
    };
  }

  String get storageValue => name;

  String get label {
    return switch (this) {
      AppThemeModePreference.system => 'Sistema',
      AppThemeModePreference.light => 'Claro',
      AppThemeModePreference.dark => 'Escuro',
    };
  }

  String get description {
    return switch (this) {
      AppThemeModePreference.system =>
        'Acompanha o tema configurado no dispositivo.',
      AppThemeModePreference.light => 'Usa a interface clara do Tatuzin.',
      AppThemeModePreference.dark => 'Usa a interface escura do Tatuzin.',
    };
  }

  IconData get icon {
    return switch (this) {
      AppThemeModePreference.system => Icons.brightness_auto_outlined,
      AppThemeModePreference.light => Icons.light_mode_outlined,
      AppThemeModePreference.dark => Icons.dark_mode_outlined,
    };
  }

  static AppThemeModePreference fromStorageValue(String? rawValue) {
    for (final mode in AppThemeModePreference.values) {
      if (mode.storageValue == rawValue) {
        return mode;
      }
    }
    return AppThemeModePreference.system;
  }
}
