import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Four offline 3D models are packaged as GLB files', () async {
    const names = <String>[
      'gold_car',
      'pearl_yacht',
      'royal_crown',
      'sky_rocket',
    ];
    for (final name in names) {
      final bytes = await rootBundle.load('assets/models/$name.glb');
      expect(bytes.lengthInBytes, greaterThan(512));
      final magic = String.fromCharCodes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, 4),
      );
      expect(magic, 'glTF');
    }
  });
}
