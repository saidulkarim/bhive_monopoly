import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/core/ui/settled_modal.dart';
import 'package:monopoly/core/ui/game_diagnostics.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  test('diagnostics remain bounded', () {
    for (var i = 0; i < 32; i++) {
      GameDiagnostics.record(
        'test',
        StateError('private payload'),
        StackTrace.empty,
      );
    }
    expect(GameDiagnostics.entries.length, 30);
    expect(GameDiagnostics.entries.last, isNot(contains('private payload')));
  });
  test('known errors and unknown errors are localized', () {
    const bn = GameText('bn');
    const en = GameText('en');
    expect(bn.errorMessage('Not enough cash.'), 'পর্যাপ্ত টাকা নেই।');
    expect(
      bn.errorMessage('Bad state: Bluetooth connection closed.'),
      'ব্লুটুথ সংযোগ বন্ধ হয়েছে।',
    );
    expect(en.errorMessage('Not enough cash.'), 'Not enough cash.');
    expect(bn.errorMessage('Minimum bid: 25.'), contains(bn.money(25)));
    expect(
      bn.errorMessage('SocketException: private technical details'),
      'কাজটি সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।',
    );
  });

  testWidgets('controller remains alive until dialog exit finishes', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final controller = TextEditingController(text: '100');
                try {
                  await showSettledDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      content: TextField(controller: controller),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                } finally {
                  controller.dispose();
                  finished = true;
                }
              },
              child: const Text('Trade'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Trade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(finished, isFalse);
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
