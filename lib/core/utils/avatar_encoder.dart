import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Run via Flutter's compute: background isolate on Android, same API on Web.
String encodeAvatar(Uint8List bytes) {
  if (bytes.length > 10 * 1024 * 1024) {
    throw const FormatException('Image exceeds 10 MiB');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  final oriented = img.bakeOrientation(decoded);
  final square = img.copyResizeCropSquare(
    oriented,
    size: 128,
    interpolation: img.Interpolation.average,
  );
  return base64Encode(img.encodeJpg(square, quality: 80));
}
