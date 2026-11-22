import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'lan_avatar_codec.dart';

/// Reduces a user-opted-in profile picture to a small JPEG for the existing
/// 64 KiB Phase-6 LAN avatar payload. Does not change the saved local photo.
/// The work runs off the UI isolate on native platforms (compute), and is
/// intentionally bounded before decode to avoid huge untrusted inputs.
class LanAvatarCompressor {
  static const int maxInputBytes = 12 * 1024 * 1024;

  static Future<Uint8List?> compress(Uint8List? bytes) async {
    if (bytes == null || bytes.length < 8 || bytes.length > maxInputBytes) {
      return null;
    }
    if (LanAvatarCodec.encode(bytes) != null) return bytes;
    try {
      final result = await compute(_compressAvatar, bytes);
      return LanAvatarCodec.encode(result) != null ? result : null;
    } catch (error) {
      debugPrint('LAN avatar resize failed: $error');
      return null;
    }
  }
}

Uint8List? _compressAvatar(Uint8List bytes) {
  // Only JPEG and PNG are accepted by the Phase-6 LAN protocol.
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;
  if (!jpeg && !png) return null;

  final decoded = img.decodeImage(bytes);
  if (decoded == null ||
      decoded.width < 1 ||
      decoded.height < 1 ||
      decoded.width * decoded.height > 16000000) {
    return null;
  }

  for (final side in <int>[256, 192, 160, 128, 96]) {
    final originalSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final scale = side / originalSide;
    final width = scale < 1 ? (decoded.width * scale).round() : decoded.width;
    final height = scale < 1
        ? (decoded.height * scale).round()
        : decoded.height;
    final resized = img.copyResize(
      decoded,
      width: width < 1 ? 1 : width,
      height: height < 1 ? 1 : height,
      interpolation: img.Interpolation.linear,
    );
    for (final quality in <int>[84, 72, 60, 45]) {
      final compressed = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );
      if (compressed.length <= LanAvatarCodec.maxBytes) return compressed;
    }
  }
  return null;
}
