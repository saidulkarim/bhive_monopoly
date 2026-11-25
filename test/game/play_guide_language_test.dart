import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/ui/screens/play_guide_screen.dart';

void main() {
  test('English language loads the English bundled guide', () {
    expect(
      PlayGuideScreen.assetForLanguage('en'),
      'assets/guides/bhive_monopoly_play_guide_en.pdf',
    );
  });

  test('Bangla language loads the Bangla bundled guide', () {
    expect(
      PlayGuideScreen.assetForLanguage('bn'),
      'assets/guides/bhive_monopoly_play_guide_bn.pdf',
    );
  });

  test('Other language values fall back to English', () {
    expect(
      PlayGuideScreen.assetForLanguage('en_US'),
      PlayGuideScreen.assetForLanguage('en'),
    );
  });
}
