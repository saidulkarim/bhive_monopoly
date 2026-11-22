// ignore_for_file: avoid_relative_lib_imports

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/game/network/lan_discovery.dart';

void main() {
  const info = LanDiscoveryInfo(
    roomId: 'abcdef123456789012345678',
    name: 'Host Player',
    players: 2,
    capacity: 5,
    hostPort: 8787,
    protocol: 3,
  );

  test('advertises limited public information; never reveals PIN', () {
    final packet = info.encode();
    final map = jsonDecode(packet) as Map<String, dynamic>;
    expect(map['signature'], LanDiscoveryInfo.signature);
    expect(map['players'], 2);
    expect(map.containsKey('pin'), isFalse);
    expect(map.containsKey('token'), isFalse);
    expect(map.containsKey('avatarData'), isFalse);
  });

  test('room discovery uses datagram source IP, not JSON host claim', () {
    final raw = jsonDecode(info.encode()) as Map<String, dynamic>;
    raw['hostIp'] = '10.0.0.6';
    final result = LanDiscoveryInfo.decode(
      jsonEncode(raw),
      sourceAddress: '192.168.1.10',
      requiredProtocol: 3,
    );
    expect(result, isNotNull);
    expect(result!.hostIp, '192.168.1.10');
    expect(result.playerCount, 2);
    expect(result.capacity, 5);
    expect(result.isFull, isFalse);
    expect(result.port, 8787);
  });

  test('version mismatch and malformed packets are ignored', () {
    expect(
      LanDiscoveryInfo.decode(
        info.encode(),
        sourceAddress: '192.168.1.10',
        requiredProtocol: 2,
      ),
      isNull,
    );
    expect(
      LanDiscoveryInfo.decode(
        '{broken json',
        sourceAddress: '192.168.1.10',
        requiredProtocol: 3,
      ),
      isNull,
    );
    expect(
      LanDiscoveryInfo.decode(
        List<String>.filled(1025, 'x').join(),
        sourceAddress: '192.168.1.10',
        requiredProtocol: 3,
      ),
      isNull,
    );
  });

  test('invalid lobby occupancy or room ID is rejected', () {
    final packet = jsonDecode(info.encode()) as Map<String, dynamic>;
    packet['players'] = 99;
    expect(
      LanDiscoveryInfo.decode(
        jsonEncode(packet),
        sourceAddress: '192.168.1.10',
        requiredProtocol: 3,
      ),
      isNull,
    );
    packet['players'] = 2;
    packet['roomId'] = 'not valid';
    expect(
      LanDiscoveryInfo.decode(
        jsonEncode(packet),
        sourceAddress: '192.168.1.10',
        requiredProtocol: 3,
      ),
      isNull,
    );
  });

  test('host may refresh displayed players', () {
    final updated = info.withPlayers(4);
    expect(updated.players, 4);
    expect(info.players, 2);
  });
}
