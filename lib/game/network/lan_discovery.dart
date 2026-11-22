// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'lan_discovery_stub.dart'
    if (dart.library.io) 'lan_discovery_native.dart'
    as platform;

/// UDP room advertisements contain public lobby details only. Never send the
/// room PIN, reconnect secret, profile photo, or game state in a discovery packet.
class LanDiscoveryInfo {
  const LanDiscoveryInfo({
    required this.roomId,
    required this.name,
    required this.players,
    required this.capacity,
    required this.hostPort,
    required this.protocol,
  });

  static const String signature = 'bhive-monopoly-lan';
  static const int discoveryVersion = 1;
  static const int udpPort = 8788;

  final String roomId;
  final String name;
  final int players;
  final int capacity;
  final int hostPort;
  final int protocol;

  LanDiscoveryInfo withPlayers(int count) => LanDiscoveryInfo(
    roomId: roomId,
    name: name,
    players: count,
    capacity: capacity,
    hostPort: hostPort,
    protocol: protocol,
  );

  String encode() => jsonEncode(<String, dynamic>{
    'signature': signature,
    'version': discoveryVersion,
    'roomId': roomId,
    'name': name,
    'players': players,
    'capacity': capacity,
    'port': hostPort,
    'protocol': protocol,
  });

  /// The host address comes from the UDP packet's SOURCE address, never a
  /// claimed address in its JSON payload. Advertisements are not authenticated;
  /// actual admission still requires the room PIN and WebSocket handshake.
  static LanDiscoveredRoom? decode(
    String raw, {
    required String sourceAddress,
    required int requiredProtocol,
    DateTime? receivedAt,
  }) {
    if (raw.length > 1024 || sourceAddress.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['signature'] != signature ||
          decoded['version'] != discoveryVersion ||
          decoded['protocol'] != requiredProtocol)
        return null;
      final id = decoded['roomId'];
      final name = decoded['name'];
      final players = decoded['players'];
      final capacity = decoded['capacity'];
      final port = decoded['port'];
      if (id is! String ||
          !RegExp(r'^[a-f0-9]{12,32}$').hasMatch(id) ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 24 ||
          players is! int ||
          capacity is! int ||
          port is! int ||
          capacity < 2 ||
          capacity > 6 ||
          players < 1 ||
          players > capacity ||
          port < 1 ||
          port > 65535)
        return null;
      return LanDiscoveredRoom(
        roomId: id,
        hostName: name.trim(),
        hostIp: sourceAddress,
        playerCount: players,
        capacity: capacity,
        port: port,
        lastSeen: receivedAt ?? DateTime.now(),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class LanDiscoveredRoom {
  const LanDiscoveredRoom({
    required this.roomId,
    required this.hostName,
    required this.hostIp,
    required this.playerCount,
    required this.capacity,
    required this.port,
    required this.lastSeen,
  });

  final String roomId;
  final String hostName;
  final String hostIp;
  final int playerCount;
  final int capacity;
  final int port;
  final DateTime lastSeen;

  String get key => '$hostIp:$port/$roomId';
  bool get isFull => playerCount >= capacity;
}

/// Native Android/Windows/macOS/Linux: UDP broadcast discovery. Flutter Web:
/// no UDP APIs, so manual host-IP joining remains available.
abstract class LanDiscoveryService extends ChangeNotifier {
  LanDiscoveryService.internal();
  factory LanDiscoveryService() => platform.createLanDiscoveryService();

  List<LanDiscoveredRoom> get rooms;
  String? get lastError;
  bool get isBrowsing;

  Future<void> startAdvertising(LanDiscoveryInfo info);
  void updateAdvertisingCount(int playerCount);
  Future<void> stopAdvertising();
  Future<void> startBrowsing({required int protocol});
  Future<void> stopBrowsing();
  Future<void> close();
}
