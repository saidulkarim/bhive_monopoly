import 'dart:math';

/// Protocol helpers shared by Web and native Flutter clients.
/// The relay transports messages; the Flutter host remains authoritative.
abstract final class RelayProtocol {
  static const int maxRoomPlayers = 6;
  static const int roomCodeLength = 8;
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static Uri endpoint(String input, {bool requireSecure = false}) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !const <String>{'ws', 'wss'}.contains(uri.scheme) ||
        (requireSecure && uri.scheme != 'wss')) {
      throw const FormatException(
        'Enter a valid WebSocket relay URL (ws:// or wss://). '
        'HTTPS websites require wss://.',
      );
    }
    return uri;
  }

  static String roomCode({Random? random}) {
    final source = random ?? Random.secure();
    return String.fromCharCodes(
      List<int>.generate(roomCodeLength, (_) {
        final position = source.nextInt(_alphabet.length);
        return _alphabet.codeUnitAt(position);
      }),
    );
  }

  static String verifiedCode(String input) {
    final code = input.trim().toUpperCase();
    if (code.length != roomCodeLength ||
        !RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      throw const FormatException('Enter the 8-character room code.');
    }
    return code;
  }
}
