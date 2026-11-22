// ignore_for_file: avoid_relative_lib_imports

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/network/lan_avatar_codec.dart';

void main() {
  final pngBytes = Uint8List.fromList(<int>[
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    0,
  ]);

  test('valid-sized PNG avatar roundtrips over wire', () {
    final encoded = LanAvatarCodec.encode(pngBytes);
    expect(encoded, isNotNull);
    expect(LanAvatarCodec.decode(encoded), pngBytes);
  });

  test('malformed images and overlarge uploads are dropped safely', () {
    expect(
      LanAvatarCodec.encode(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
      isNull,
    );
    expect(
      LanAvatarCodec.encode(
        Uint8List.fromList(<int>[
          ...pngBytes,
          ...List<int>.filled(LanAvatarCodec.maxBytes, 0),
        ]),
      ),
      isNull,
    );
    expect(LanAvatarCodec.decode('%%not base64'), isNull);
    expect(
      LanAvatarCodec.decode(
        List<String>.filled(LanAvatarCodec.maxEncodedLength + 1, 'A').join(),
      ),
      isNull,
    );
  });

  test('preset identifiers are bounded', () {
    expect(LanAvatarCodec.preset(5), 5);
    expect(LanAvatarCodec.preset(-1), 0);
    expect(LanAvatarCodec.preset(9000), 0);
    expect(LanAvatarCodec.preset('2'), 0);
  });
}
