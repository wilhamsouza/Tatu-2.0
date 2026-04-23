import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger();

  void info(String message) {
    debugPrint('[Tatuzin][INFO] $message');
  }

  void warning(String message) {
    debugPrint('[Tatuzin][WARN] $message');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[Tatuzin][ERROR] $message');
    if (error != null) {
      debugPrint(error.toString());
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
