import 'dart:async';
import 'dart:io';

import 'lan_host_transport.dart';

LanHostTransport createLanHostTransport(int port) => _NativeHost(port);

class _NativeHost implements LanHostTransport {
  _NativeHost(this.port);

  final int port;
  final Set<WebSocket> _sockets = <WebSocket>{};
  HttpServer? _server;
  List<String> _addresses = <String>[];

  @override
  List<String> get addresses => List<String>.unmodifiable(_addresses);

  @override
  Future<void> start({
    required void Function(Object, String) onMessage,
    required void Function(Object) onDisconnect,
  }) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      _addresses = <String>{
        for (final item in interfaces)
          for (final address in item.addresses)
            if (!address.isLoopback && !address.address.startsWith('169.254.'))
              address.address,
      }.toList();
    } catch (_) {
      _addresses = <String>[];
    }
    _server!.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.pingInterval = const Duration(seconds: 8);
        _sockets.add(socket);
        socket.listen(
          (event) {
            if (event is String) onMessage(socket, event);
          },
          onDone: () {
            _sockets.remove(socket);
            onDisconnect(socket);
          },
          onError: (_) {
            _sockets.remove(socket);
            onDisconnect(socket);
          },
          cancelOnError: true,
        );
      } catch (_) {
        // Bad upgrade requests are ignored; connected peers stay unaffected.
      }
    });
  }

  @override
  void send(Object connection, String message) {
    final socket = connection as WebSocket;
    if (socket.readyState == WebSocket.open) socket.add(message);
  }

  @override
  Future<void> close() async {
    for (final socket in _sockets.toList()) {
      try {
        await socket.close(WebSocketStatus.goingAway);
      } catch (_) {}
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
