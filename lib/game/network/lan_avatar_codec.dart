import 'dart:convert';
import 'dart:typed_data';

/// Safely bounded avatar payloads for an unencrypted LOCAL Wi-Fi room.
/// JPEG/PNG only, max 64 KiB. Oversized photos use the preset avatar instead.
class LanAvatarCodec {
  static const int maxBytes = 64 * 1024;
  static const int maxEncodedLength = 87384;
  static const int presetCount = 6;

  static int preset(Object? raw) =>
      raw is int && raw >= 0 && raw < presetCount ? raw : 0;

  static bool _isSupportedImage(List<int> bytes) {
    if (bytes.length < 8) return false;
    final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final png =
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    return jpeg || png;
  }

  static String? encode(Uint8List? bytes) {
    if (bytes == null ||
        bytes.length < 8 ||
        bytes.length > maxBytes ||
        !_isSupportedImage(bytes)) {
      return null;
    }
    return base64Encode(bytes);
  }

  static Uint8List? decode(Object? text) {
    if (text is! String || text.isEmpty || text.length > maxEncodedLength) {
      return null;
    }
    try {
      final bytes = base64Decode(text);
      return bytes.length <= maxBytes && _isSupportedImage(bytes)
          ? Uint8List.fromList(bytes)
          : null;
    } on FormatException {
      return null;
    }
  }
}
