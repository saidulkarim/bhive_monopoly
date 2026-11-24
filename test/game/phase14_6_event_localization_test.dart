import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/ui/game_text.dart';

void main() {
  const bn = GameText('bn');
  const en = GameText('en');
  test('Updated property names', () {
    const names = {
      11: 'নোয়াখালী',
      14: 'কুমিল্লা',
      16: 'রাজশাহী',
      18: 'ময়মনসিংহ',
      19: 'বগুড়া',
      31: 'গুলশান-১',
      32: 'গুলশান-২',
      34: 'বনানী',
      37: 'নিকেতন',
    };
    for (final entry in names.entries) {
      expect(bn.spaceName(entry.key, ''), entry.value);
    }
  });
  test('Same canonical events render in either language', () {
    const purchase = 'Lenovo purchased North Station for 200.';
    expect(bn.eventText(purchase), 'Lenovo ৳২০০ দিয়ে বিমানবন্দর কিনেছেন।');
    expect(
      en.eventText(purchase),
      r'Lenovo purchased Airport Railway for $200.',
    );
    expect(
      bn.eventText('Iris landed on Harbor Square.'),
      'Iris পটুয়াখালী ঘরে এসেছেন।',
    );
    expect(
      bn.eventText('Lenovo rolled 6 + 5 = 11.'),
      'Lenovo পাশা ফেলেছেন: ৬ + ৫ = ১১।',
    );
    expect(
      bn.eventText('Iris paid 8 rent to Lenovo.'),
      'Iris Lenovo-কে ৳৮ ভাড়া দিয়েছেন।',
    );
    expect(bn.eventText("Lenovo’s turn."), 'এখন Lenovo-এর পালা।');
    expect(bn.eventText('Tax paid: 200.'), 'কর পরিশোধ: ৳২০০।');
    expect(
      bn.eventText('Fortune: Travel to Central Station.'),
      'ভাগ্য পরীক্ষা: কমলাপুরে যান।',
    );
    expect(bn.eventText('Unknown message'), 'Unknown message');
  });
}
