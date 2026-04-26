import 'dart:async';

import 'package:flutter/foundation.dart';

class StartupTrace {
  StartupTrace._();

  static const bool _enabled =
      bool.fromEnvironment('STARTUP_TRACE', defaultValue: false);
  static final Stopwatch _appStopwatch = Stopwatch()..start();

  static void mark(String message) {
    if (!_enabled || !kDebugMode) {
      return;
    }
    final elapsed = _appStopwatch.elapsedMilliseconds.toString().padLeft(5, ' ');
    debugPrint('[STARTUP +${elapsed}ms] $message');
  }

  static Future<T> time<T>(String label, Future<T> Function() action) async {
    if (!_enabled || !kDebugMode) {
      return action();
    }
    final stopwatch = Stopwatch()..start();
    mark('$label START');
    try {
      return await action();
    } finally {
      stopwatch.stop();
      mark('$label END (${stopwatch.elapsedMilliseconds}ms)');
    }
  }
}
