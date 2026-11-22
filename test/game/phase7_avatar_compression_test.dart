import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:monopoly/game/network/lan_avatar_codec.dart';
import 'package:monopoly/game/network/lan_avatar_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'compresses a noisy oversized PNG without modifying source bytes',
    () async {
      final image = img.Image(width: 512, height: 512);
      final random = Random(123);
      for (var y = 0; y < 512; y++) {
        for (var x = 0; x < 512; x++) {
          image.setPixelRgba(
            x,
            y,
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
            255,
          );
        }
      }
      final input = Uint8List.fromList(img.encodePng(image));
      expect(input.length, greaterThan(LanAvatarCodec.maxBytes));
      final originalLength = input.length;
      final output = await LanAvatarCompressor.compress(input);
      expect(output, isNotNull);
      expect(LanAvatarCodec.encode(output), isNotNull);
      expect(input.length, originalLength); // local image stays untouched.
      final decoded = img.decodeImage(output!);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(256));
      expect(decoded.height, lessThanOrEqualTo(256));
    },
  );

  test('rejects invalid and unreasonably large input', () async {
    expect(
      await LanAvatarCompressor.compress(Uint8List.fromList([1, 2, 3])),
      isNull,
    );
    expect(
      await LanAvatarCompressor.compress(Uint8List(12 * 1024 * 1024 + 1)),
      isNull,
    );
    expect(await LanAvatarCompressor.compress(null), isNull);
  });
}
