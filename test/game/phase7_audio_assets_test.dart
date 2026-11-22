import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monopoly/game/experience/game_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all seven sound assets are packaged as valid RIFF WAV', () async {
    for (final effect in GameSfx.values) {
      final sound = await rootBundle.load('assets/audio/${effect.filename}');
      expect(sound.lengthInBytes, greaterThan(44));
      final header = String.fromCharCodes(sound.buffer.asUint8List(0, 4));
      expect(header, 'RIFF');
    }
  });
}
