import 'dart:async';

/// One-shot, single-flight operation monitor. A timeout is advisory: it
/// never releases the operation lock or starts another command.
class AiOperationWatchdog {
  AiOperationWatchdog({required this.timeout, required this.onTimeout});

  final Duration timeout;
  final void Function() onTimeout;
  Timer? _timer;
  bool _running = false;
  bool _monitor = true;
  bool _disposed = false;
  bool _timedOut = false;

  bool get running => _running;
  bool get timedOut => _timedOut;

  bool begin({bool monitor = true}) {
    if (_disposed || _running) return false;
    _running = true;
    _monitor = monitor;
    _timedOut = false;
    if (monitor) _arm();
    return true;
  }

  void _arm() {
    _timer?.cancel();
    if (!_running || _disposed || _timedOut || !_monitor) return;
    _timer = Timer(timeout, () {
      _timer = null;
      if (!_running || _disposed) return;
      _timedOut = true;
      onTimeout();
    });
  }

  /// Human decisions have no automated timeout. Keep the operation locked.
  void suspendDeadline() {
    _timer?.cancel();
    _timer = null;
  }

  void resumeDeadline() => _arm();

  void finish() {
    suspendDeadline();
    _running = false;
  }

  void dispose() {
    _disposed = true;
    finish();
  }
}
