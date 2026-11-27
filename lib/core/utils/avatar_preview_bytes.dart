import 'dart:convert';
import 'dart:typed_data';

import '../config/game_config.dart';

/// One entry per owning screen. Stable bytes give MemoryImage a stable key
/// across unrelated rebuilds. No global retention or cache-clearing loop.
class AvatarPreviewBytes {
  String? _encoded;
  Uint8List? _bytes;

  Uint8List? resolve(String? encoded) {
    if (!GameConfig.reuseAvatarPreviewBytesEnabled) {
      return _decode(encoded);
    }
    if (_encoded != encoded) {
      _encoded = encoded;
      _bytes = _decode(encoded);
    }
    return _bytes;
  }

  static Uint8List? _decode(String? encoded) {
    if (encoded == null) return null;
    try {
      return base64Decode(encoded).asUnmodifiableView();
    } on FormatException {
      return null;
    }
  }
}
