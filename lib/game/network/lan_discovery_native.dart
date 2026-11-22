import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lan_discovery.dart';

LanDiscoveryService createLanDiscoveryService() => _NativeDiscovery();

class _NativeDiscovery extends LanDiscoveryService {
  _NativeDiscovery() : super.internal();
  RawDatagramSocket? _advertiser;
  RawDatagramSocket? _listener;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  LanDiscoveryInfo? _advertisement;
  int _requiredProtocol = -1;
  final Map<String, LanDiscoveredRoom> _found = <String, LanDiscoveredRoom>{};
  String? _lastError;
  bool _closed = false;
  bool _browsing = false;

  @override
  List<LanDiscoveredRoom> get rooms => List<LanDiscoveredRoom>.unmodifiable(
    _found.values.toList()..sort(
      (a, b) => a.hostName.toLowerCase().compareTo(b.hostName.toLowerCase()),
    ),
  );
  @override
  String? get lastError => _lastError;
  @override
  bool get isBrowsing => _browsing;

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  Future<void> startAdvertising(LanDiscoveryInfo info) async {
    await stopAdvertising();
    if (_closed) return;
    _advertisement = info;
    try {
      _advertiser = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _advertiser!.broadcastEnabled = true;
      _advertiseOnce();
      _broadcastTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _advertiseOnce(),
      );
    } on SocketException catch (e) {
      _lastError = 'Wi-Fi room advertising unavailable: $e';
      await stopAdvertising();
      _notify();
    }
  }

  void _advertiseOnce() {
    final socket = _advertiser;
    final info = _advertisement;
    if (socket == null || info == null || _closed) return;
    try {
      final bytes = utf8.encode(info.encode());
      socket.send(
        bytes,
        InternetAddress('255.255.255.255'),
        LanDiscoveryInfo.udpPort,
      );
    } on SocketException {
      // Some networks prohibit broadcast. Manual IP join still works.
    }
  }

  @override
  void updateAdvertisingCount(int playerCount) {
    final info = _advertisement;
    if (info == null || playerCount < 1 || playerCount > info.capacity) return;
    _advertisement = info.withPlayers(playerCount);
    _advertiseOnce();
  }

  @override
  Future<void> stopAdvertising() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _advertiser?.close();
    _advertiser = null;
    _advertisement = null;
  }

  @override
  Future<void> startBrowsing({required int protocol}) async {
    await stopBrowsing();
    if (_closed) return;
    _requiredProtocol = protocol;
    _lastError = null;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        LanDiscoveryInfo.udpPort,
        reuseAddress: true,
      );
      _listener = socket;
      _browsing = true;
      _subscription = socket.listen(
        (event) {
          if (_closed || event != RawSocketEvent.read) return;
          Datagram? datagram;
          while ((datagram = socket.receive()) != null) {
            final packet = datagram!;
            if (packet.data.length > 1024) continue;
            final decoded = LanDiscoveryInfo.decode(
              utf8.decode(packet.data, allowMalformed: true),
              sourceAddress: packet.address.address,
              requiredProtocol: _requiredProtocol,
            );
            if (decoded == null) continue;
            _found[decoded.key] = decoded;
            _notify();
          }
        },
        onError: (Object error) {
          _lastError = 'Wi-Fi scan interrupted: $error';
          _notify();
        },
      );
      _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
        final before = _found.length;
        _found.removeWhere((key, room) => room.lastSeen.isBefore(cutoff));
        if (before != _found.length) _notify();
      });
      _notify();
    } on SocketException catch (e) {
      _lastError = 'Cannot scan local Wi-Fi: $e';
      _browsing = false;
      _notify();
    }
  }

  @override
  Future<void> stopBrowsing() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _listener?.close();
    _listener = null;
    _browsing = false;
    _found.clear();
    _notify();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    await stopAdvertising();
    await stopBrowsing();
    _closed = true;
    dispose();
  }
}
