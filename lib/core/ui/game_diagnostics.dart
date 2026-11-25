import 'package:flutter/foundation.dart';

/// Session-only diagnostics; no timers, persistence or network traffic.
class GameDiagnostics {
  static final List<String> _entries = [];
  static List<String> get entries => List.unmodifiable(_entries);

  static void record(String operation, Object error, StackTrace stack) {
    final entry =
        '${DateTime.now().toUtc().toIso8601String()} $operation: ${error.runtimeType}\n$stack';
    _entries.add(entry.length > 6000 ? entry.substring(0, 6000) : entry);
    if (_entries.length > 30) _entries.removeAt(0);
    debugPrint(entry);
  }
}
