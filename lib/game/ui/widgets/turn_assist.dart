import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/config/game_config.dart';
import '../../../core/ui/app_notices.dart';
import '../../../core/ui/game_diagnostics.dart';
import '../game_text.dart';

/// Only schedules work while End Turn is available. Route and lifecycle
/// checks prevent actions behind dialogs or while the application is hidden.
class TurnAssist extends StatefulWidget {
  const TurnAssist({
    super.key,
    required this.child,
    required this.turnKey,
    required this.eligible,
    required this.text,
    this.onAutoEnd,
  });
  final Widget child;
  final String? turnKey;
  final bool Function() eligible;
  final GameText text;
  final VoidCallback? onAutoEnd;
  @override
  State<TurnAssist> createState() => _TurnAssistState();
}

class _TurnAssistState extends State<TurnAssist> with WidgetsBindingObserver {
  Timer? _timer;
  bool _foreground = true;
  bool _routeCurrent = false;
  int _epoch = 0;
  bool get _safe =>
      mounted &&
      _foreground &&
      widget.turnKey != null &&
      _routeCurrent &&
      ModalRoute.of(context)?.isCurrent == true &&
      widget.eligible();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.isCurrentOf(context) == true;
    if (current != _routeCurrent) {
      _routeCurrent = current;
      _restart();
    }
  }

  @override
  void didUpdateWidget(covariant TurnAssist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.turnKey != widget.turnKey) _restart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    final epoch = ++_epoch;
    if (!GameConfig.smartTurnAssistEnabled ||
        !_foreground ||
        !_routeCurrent ||
        widget.turnKey == null) {
      return;
    }
    _schedule(GameConfig.endTurnReminderSeconds, epoch, () {
      _notice(
        widget.text.choose(
          'Your turn is complete. Tap End Turn to continue.',
          'আপনার চাল সম্পন্ন হয়েছে। পরবর্তী খেলোয়াড়ের জন্য চাল শেষ করুন।',
        ),
      );
      if (widget.onAutoEnd == null || !GameConfig.humanAutoEndTurnEnabled) {
        return;
      }
      final warning =
          GameConfig.autoEndTurnSeconds -
          GameConfig.autoEndTurnCountdownSeconds;
      if (warning < GameConfig.endTurnReminderSeconds ||
          GameConfig.autoEndTurnCountdownSeconds <= 0) {
        return;
      }
      _schedule(warning - GameConfig.endTurnReminderSeconds, epoch, () {
        final seconds = GameConfig.autoEndTurnCountdownSeconds;
        _notice(
          widget.text.choose(
            'Your turn will end automatically in $seconds seconds.',
            'আপনার চাল ${widget.text.integer(seconds)} সেকেন্ডের মধ্যে স্বয়ংক্রিয়ভাবে শেষ হবে।',
          ),
        );
        _schedule(seconds, epoch, () => widget.onAutoEnd?.call());
      });
    });
  }

  void _schedule(int seconds, int epoch, VoidCallback action) {
    _timer = Timer(Duration(seconds: seconds), () {
      if (!mounted || epoch != _epoch) return;
      try {
        if (!_safe) return;
        action();
      } catch (error, stack) {
        GameDiagnostics.record('turn assist', error, stack);
      }
    });
  }

  void _notice(String message) =>
      AppNotices.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _restart(),
    onPointerSignal: (_) => _restart(),
    child: widget.child,
  );
}
