import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/ui/game_text.dart';
import 'package:monopoly/game/ui/widgets/game_activity_sheet.dart';

void main() {
  test('Currency uses the game language and correct grouping', () {
    const en = GameText('en');
    const bn = GameText('bn');
    expect(en.money(1500), r'$1,500');
    expect(bn.money(1500), '৳১,৫০০');
    expect(en.money(1250000), r'$12,50,000');
    expect(bn.money(1250000), '৳১২,৫০,০০০');
    expect(en.money(0), r'$0');
    expect(bn.money(0), '৳০');
  });

  test('Existing engine logs gain symbols but remain otherwise unchanged', () {
    const t = GameText('en');
    expect(
      t.moneyInEvent('Computer 1 paid 12 rent to Player.'),
      r'Computer 1 paid $12 rent to Player.',
    );
    expect(
      t.moneyInEvent('Player purchased Maple Boulevard for 220.'),
      r'Player purchased Maple Boulevard for $220.',
    );
    expect(t.moneyInEvent('Tax paid: 200.'), r'Tax paid: $200.');
    expect(
      t.moneyInEvent('Player passed START and earned 200.'),
      r'Player passed START and earned $200.',
    );
    expect(t.moneyInEvent('Computer 1 bids 50.'), r'Computer 1 bids $50.');
    expect(t.moneyInEvent('Minimum bid: 10.'), r'Minimum bid: $10.');
    expect(
      t.moneyInEvent('Built on River Walk for 50.'),
      r'Built on River Walk for $50.',
    );
    expect(
      t.moneyInEvent('Canal Street mortgaged for 30.'),
      r'Canal Street mortgaged for $30.',
    );
  });

  test('Fortune and City Chest card amounts are formatted independently', () {
    const t = GameText('en');
    expect(
      t.moneyInEvent('Fortune: Pay each other player 50.'),
      r'Fortune: Pay each other player $50.',
    );
    expect(
      t.moneyInEvent(
        'Fortune: Make city repairs: pay 25 per house and 100 per hotel.',
      ),
      r'Fortune: Make city repairs: pay $25 per house and $100 per hotel.',
    );
    expect(
      t.moneyInEvent('City Chest: Receive 200 in city grants.'),
      r'City Chest: Receive $200 in city grants.',
    );
  });

  test('Money formatter never changes dice, player numbers, or turn count', () {
    const t = GameText('en');
    const line = 'Computer 1 rolled 6 + 6 = 12.';
    expect(t.moneyInEvent(line), line);
    expect(
      t.moneyInEvent('Jail attempt 2/3 failed.'),
      'Jail attempt 2/3 failed.',
    );
    expect(t.moneyInEvent('TURN 11'), 'TURN 11');
    expect(
      t.moneyInEvent('Player landed on River Walk.'),
      'Player landed on River Walk.',
    );
    // Already-localized text must not receive a second currency symbol.
    expect(t.moneyInEvent(r'Player paid $25 rent.'), r'Player paid $25 rent.');
  });

  test('Bangla display uses taka and Bengali digits for money values', () {
    const t = GameText('bn');
    expect(
      t.moneyInEvent('Computer 1 paid 12 rent to Player.'),
      'Computer 1 paid ৳১২ rent to Player.',
    );
    expect(
      t.moneyInEvent('Player purchased Maple Boulevard for 220.'),
      'Player purchased Maple Boulevard for ৳২২০.',
    );
    expect(
      t.moneyInEvent('Fortune: Pay each other player 50.'),
      'Fortune: Pay each other player ৳৫০.',
    );
  });

  testWidgets('Expanded activity shows currency for both monetary events', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameActivitySheet(
            text: GameText('en'),
            events: <String>[
              'Computer 1 paid 12 rent to Player.',
              'Player purchased Maple Boulevard for 220.',
            ],
          ),
        ),
      ),
    );
    expect(find.text(r'Computer 1 paid $12 rent to Player.'), findsOneWidget);
    expect(
      find.text(r'Player purchased Maple Boulevard for $220.'),
      findsOneWidget,
    );
  });
}
