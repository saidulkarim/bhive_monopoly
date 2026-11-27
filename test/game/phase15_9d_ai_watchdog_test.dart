import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/ui/widgets/ai_operation_watchdog.dart';

void main() {
  const deadline = Duration(seconds: 30);

  testWidgets('normal completion cancels deadline and releases lock', (
    tester,
  ) async {
    var timeouts = 0;
    final guard = AiOperationWatchdog(
      timeout: deadline,
      onTimeout: () => timeouts++,
    );
    expect(guard.begin(), isTrue);
    expect(guard.begin(), isFalse);
    guard.finish();
    await tester.pump(deadline);
    expect(timeouts, 0);
    expect(guard.begin(), isTrue);
    guard.dispose();
  });

  testWidgets(
    'timeout fires once and does not release an unfinished operation',
    (tester) async {
      var timeouts = 0;
      final guard = AiOperationWatchdog(
        timeout: deadline,
        onTimeout: () => timeouts++,
      );
      guard.begin();
      await tester.pump(deadline);
      expect(guard.timedOut, isTrue);
      expect(guard.running, isTrue);
      expect(guard.begin(), isFalse);
      await tester.pump(deadline);
      expect(timeouts, 1);
      guard.finish();
      expect(guard.begin(), isTrue);
      expect(guard.timedOut, isFalse);
      guard.dispose();
    },
  );

  testWidgets('human response suspends deadline without releasing lock', (
    tester,
  ) async {
    var timeouts = 0;
    final guard = AiOperationWatchdog(
      timeout: deadline,
      onTimeout: () => timeouts++,
    );
    guard.begin();
    guard.suspendDeadline();
    await tester.pump(deadline * 3);
    expect(timeouts, 0);
    expect(guard.begin(), isFalse);
    guard.resumeDeadline();
    await tester.pump(deadline);
    expect(timeouts, 1);
    guard.dispose();
  });

  testWidgets('dispose cancels pending deadline and prevents reuse', (
    tester,
  ) async {
    var timeouts = 0;
    final guard = AiOperationWatchdog(
      timeout: deadline,
      onTimeout: () => timeouts++,
    );
    guard.begin();
    guard.dispose();
    guard.resumeDeadline();
    await tester.pump(deadline);
    expect(timeouts, 0);
    expect(guard.begin(), isFalse);
  });

  testWidgets('disabled monitoring still serializes automated operations', (
    tester,
  ) async {
    var timeouts = 0;
    final guard = AiOperationWatchdog(
      timeout: deadline,
      onTimeout: () => timeouts++,
    );
    guard.begin(monitor: false);
    await tester.pump(deadline);
    expect(timeouts, 0);
    expect(guard.begin(), isFalse);
    guard.dispose();
  });
}
