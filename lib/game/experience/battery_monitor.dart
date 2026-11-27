import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/game_config.dart';
import 'adaptive_power_policy.dart';
import 'game_experience_settings.dart';

typedef BatteryReader = Future<BatteryReading?> Function();

/// No subscription or timer when disabled or hidden. A failed/unsupported
/// platform read falls back to the manually selected profile.
class BatteryMonitor {
  BatteryMonitor(this.settings, {BatteryReader? reader})
    : _reader = reader ?? _readPlatform;
  final GameExperienceSettings settings;
  final BatteryReader _reader;
  Timer? _timer;
  bool _foreground = false;
  bool _enabled = false;
  bool _disposed = false;
  bool _busy = false;
  int _epoch = 0;

  static Future<BatteryReading?> _readPlatform() async {
    // Browser Battery API availability and reported defaults vary; keep the
    // selected profile on Web and unsupported desktop platforms.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final battery = Battery();
    final state = await battery.batteryState;
    final level = await battery.batteryLevel;
    if (state != BatteryState.charging &&
        state != BatteryState.full &&
        state != BatteryState.discharging) {
      return null;
    }
    return BatteryReading(level, charging: state != BatteryState.discharging);
  }

  void configure({required bool foreground, required bool enabled}) {
    if (_disposed || (_foreground == foreground && _enabled == enabled)) return;
    _foreground = foreground;
    _enabled = enabled;
    _epoch++;
    _timer?.cancel();
    _timer = null;
    if (_active && !_busy) unawaited(_sample());
  }

  bool get _active => !_disposed && _foreground && _enabled;

  Future<void> _sample() async {
    if (!_active || _busy) return;
    _busy = true;
    final epoch = _epoch;
    BatteryReading? reading;
    try {
      reading = await _reader().timeout(
        const Duration(seconds: GameConfig.batterySampleTimeoutSeconds),
      );
    } catch (_) {
      reading = null;
    } finally {
      _busy = false;
    }
    if (!_active) return;
    if (epoch != _epoch) {
      unawaited(_sample());
      return;
    }
    settings.updateBatteryReading(reading?.valid == true ? reading : null);
    if (!_active || epoch != _epoch) return;
    // No periodic work on unsupported platforms. On Android a temporary
    // unavailable reading is retried at the normal low frequency.
    if (reading == null &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    _timer = Timer(
      const Duration(seconds: GameConfig.batterySampleIntervalSeconds),
      () {
        _timer = null;
        unawaited(_sample());
      },
    );
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    _timer = null;
  }
}
