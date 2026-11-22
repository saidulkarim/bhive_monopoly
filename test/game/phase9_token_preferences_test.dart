import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:monopoly/game/experience/token_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'six original defaults; selections persist after re-instantiation',
    () async {
      final preferences = TokenPreferences();
      await preferences.ensureLoaded();
      for (var i = 0; i < 6; i++) {
        expect(preferences.selectionFor(i), i);
      }
      await preferences.select(0, 3);
      await preferences.select(5, 1);
      expect(preferences.styleFor(0).key, 'rocket');

      final restarted = TokenPreferences();
      await restarted.ensureLoaded();
      expect(restarted.selectionFor(0), 3);
      expect(restarted.selectionFor(5), 1);
      expect(restarted.selectionFor(1), 1);
    },
  );

  test('reset restores defaults; invalid selections do not write', () async {
    final preferences = TokenPreferences();
    await preferences.ensureLoaded();
    await preferences.select(2, 5);
    expect(preferences.selectionFor(2), 5);
    await preferences.restoreDefaults();
    expect(preferences.selectionFor(2), 2);

    await expectLater(preferences.select(-1, 1), throwsRangeError);
    await expectLater(preferences.select(0, 999), throwsRangeError);
    expect(preferences.selectionFor(0), 0);
  });

  test('corrupt or missing style values fall back safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TokenPreferences.storageKey: <String>[
        'bogus',
        '-2',
        '300',
        '2',
        '0',
        '5',
      ],
    });
    final preferences = TokenPreferences();
    await preferences.ensureLoaded();
    expect(preferences.selectionFor(0), 0);
    expect(preferences.selectionFor(1), 1);
    expect(preferences.selectionFor(2), 2);
    expect(preferences.selectionFor(3), 2);
    expect(preferences.selectionFor(4), 0);
    expect(preferences.selectionFor(5), 5);
  });
}
