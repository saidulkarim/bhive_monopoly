import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../core/config/game_config.dart';

/// Opt-in bounded aggregate only; no per-frame notification or retained list.
class PerformanceDiagnostics extends ChangeNotifier {
  static final instance = PerformanceDiagnostics();
  bool _active = false;
  bool get active => _active;
  bool _foreground = true;
  int frames = 0;
  int overBudget = 0;
  int _totalMicros = 0;
  int worstMicros = 0;
  Timer? _deadline;
  double get averageMilliseconds =>
      frames == 0 ? 0 : _totalMicros / frames / 1000;

  void start() {
    if (_active || !_foreground) return;
    frames = 0;
    overBudget = 0;
    _totalMicros = 0;
    worstMicros = 0;
    _active = true;
    SchedulerBinding.instance.addTimingsCallback(_collect);
    _deadline = Timer(
      const Duration(seconds: GameConfig.performanceDiagnosticsSessionSeconds),
      stop,
    );
    notifyListeners();
  }

  void _collect(List<FrameTiming> timings) {
    if (!_active) return;
    for (final timing in timings) {
      final micros = timing.totalSpan.inMicroseconds;
      frames++;
      _totalMicros += micros;
      if (micros > worstMicros) worstMicros = micros;
      if (micros > GameConfig.performanceFrameBudgetMilliseconds * 1000) {
        overBudget++;
      }
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) stop();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void stop() {
    if (!_active) return;
    _active = false;
    _deadline?.cancel();
    _deadline = null;
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    notifyListeners();
  }
}
