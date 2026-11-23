import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/network/relay_protocol.dart';

void main() {
  test('relay URLs support secure WebSockets and optional IIS subpath', () {
    final uri = RelayProtocol.endpoint(
      'wss://games.example.org/bhive-relay/ws',
      requireSecure: true,
    );
    expect(uri.host, 'games.example.org');
    expect(uri.path, '/bhive-relay/ws');
    expect(uri.scheme, 'wss');
    expect(
      () => RelayProtocol.endpoint('ws://example.org/ws', requireSecure: true),
      throwsFormatException,
    );
    expect(
      () => RelayProtocol.endpoint('https://example.org/ws'),
      throwsFormatException,
    );
  });

  test('room codes are shareable and validated case-insensitively', () {
    final code = RelayProtocol.roomCode();
    expect(code.length, 8);
    expect(RelayProtocol.verifiedCode(code.toLowerCase()), code);
    expect(() => RelayProtocol.verifiedCode('123456'), throwsFormatException);
    expect(() => RelayProtocol.verifiedCode('ABCD0I1O'), throwsFormatException);
  });
}
