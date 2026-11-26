import 'package:flutter/widgets.dart';

import '../config/game_config.dart';

/// A single app lifecycle observer for decorative rendering. Does not pause
/// game logic, network traffic, or awaited gameplay animations.
class VisualActivityScope extends StatefulWidget {
  const VisualActivityScope({super.key, required this.child});
  final Widget child;

  static bool isForegroundOf(BuildContext context) =>
      !GameConfig.advancedBatteryOptimizationEnabled ||
      (context
              .dependOnInheritedWidgetOfExactType<_VisualActivity>()
              ?.foreground ??
          true);

  @override
  State<VisualActivityScope> createState() => _VisualActivityScopeState();
}

class _VisualActivityScopeState extends State<VisualActivityScope>
    with WidgetsBindingObserver {
  late bool _foreground;

  static bool _visible(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;

  @override
  void initState() {
    super.initState();
    _foreground = _visible(WidgetsBinding.instance.lifecycleState);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _visible(state);
    if (mounted && foreground != _foreground) {
      setState(() => _foreground = foreground);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _VisualActivity(foreground: _foreground, child: widget.child);
}

class _VisualActivity extends InheritedWidget {
  const _VisualActivity({required this.foreground, required super.child});
  final bool foreground;

  @override
  bool updateShouldNotify(_VisualActivity oldWidget) =>
      foreground != oldWidget.foreground;
}
