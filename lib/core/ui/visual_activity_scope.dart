import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../config/game_config.dart';
import '../../game/experience/battery_monitor.dart';
import '../../game/experience/game_experience_settings.dart';
import '../../game/experience/performance_diagnostics.dart';

/// Single lifecycle observer and one-shot visual idle deadline. Neither
/// signal is a game pause: callers must opt in only for optional decoration.
class VisualActivityScope extends StatefulWidget {
  const VisualActivityScope({super.key, required this.child});
  final Widget child;

  static bool isForegroundOf(BuildContext context) =>
      !GameConfig.advancedBatteryOptimizationEnabled ||
      (context
              .dependOnInheritedWidgetOfExactType<_VisualActivity>()
              ?.foreground ??
          true);

  /// Separate dependency so idle changes do not notify dice or other
  /// consumers that only care about application visibility.
  static bool allowsIdleDecorationOf(BuildContext context) =>
      !GameConfig.advancedBatteryOptimizationEnabled ||
      !GameConfig.smartVisualIdleEnabled ||
      !(context.dependOnInheritedWidgetOfExactType<_VisualIdle>()?.idle ??
          false);

  @override
  State<VisualActivityScope> createState() => _VisualActivityScopeState();
}

class _VisualActivityScopeState extends State<VisualActivityScope>
    with WidgetsBindingObserver {
  late bool _foreground;
  bool _idle = false;
  Timer? _deadline;
  Duration? _lastMotion;
  final _settings = GameExperienceSettings.instance;
  late final BatteryMonitor _batteryMonitor;

  void _syncPower() {
    _batteryMonitor.configure(
      foreground: _foreground,
      enabled: _settings.automaticPowerEnabled,
    );
  }

  static bool get _enabled =>
      GameConfig.advancedBatteryOptimizationEnabled &&
      GameConfig.smartVisualIdleEnabled;

  static bool _visible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void initState() {
    super.initState();
    _foreground = _visible(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
    _batteryMonitor = BatteryMonitor(_settings);
    _settings.addListener(_syncPower);
    unawaited(
      _settings.ensureLoaded().then((_) {
        if (mounted) _syncPower();
      }),
    );
    PerformanceDiagnostics.instance.setForeground(_foreground);
    if (_enabled) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _arm();
    }
  }

  void _arm() {
    _deadline?.cancel();
    _deadline = null;
    if (!_enabled || !_foreground) return;
    _deadline = Timer(
      const Duration(seconds: GameConfig.idleAnimationSuspendSeconds),
      () {
        _deadline = null;
        if (mounted && _foreground && !_idle) {
          setState(() => _idle = true);
        }
      },
    );
  }

  void _activity() {
    if (!_enabled || !_foreground || !mounted) return;
    if (_idle) setState(() => _idle = false);
    _arm();
  }

  void _motion(PointerEvent event) {
    final last = _lastMotion;
    if (_idle ||
        last == null ||
        event.timeStamp < last ||
        event.timeStamp - last >=
            const Duration(
              milliseconds: GameConfig.visualIdleMotionSampleMilliseconds,
            )) {
      _lastMotion = event.timeStamp;
      _activity();
    }
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) _activity();
    return false; // Never consume gameplay shortcuts or text input.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _visible(state);
    if (!mounted || foreground == _foreground) return;
    _deadline?.cancel();
    _deadline = null;
    _lastMotion = null;
    setState(() {
      _foreground = foreground;
      _idle = false;
    });
    _syncPower();
    PerformanceDiagnostics.instance.setForeground(foreground);
    if (foreground) _arm();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _settings.removeListener(_syncPower);
    _batteryMonitor.dispose();
    PerformanceDiagnostics.instance.setForeground(false);
    if (_enabled) HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _VisualActivity(
      foreground: _foreground,
      child: _VisualIdle(idle: _idle, child: widget.child),
    );
    if (!_enabled) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _activity(),
      onPointerUp: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      onPointerMove: _motion,
      onPointerPanZoomUpdate: _motion,
      child: child,
    );
  }
}

class _VisualActivity extends InheritedWidget {
  const _VisualActivity({required this.foreground, required super.child});
  final bool foreground;

  @override
  bool updateShouldNotify(_VisualActivity oldWidget) =>
      foreground != oldWidget.foreground;
}

class _VisualIdle extends InheritedWidget {
  const _VisualIdle({required this.idle, required super.child});
  final bool idle;

  @override
  bool updateShouldNotify(_VisualIdle oldWidget) => idle != oldWidget.idle;
}
