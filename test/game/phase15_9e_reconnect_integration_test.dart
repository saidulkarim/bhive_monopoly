// Native VM loopback integration tests. Production network code has no dart:io
// import and remains shared with the web build.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly/game/engine/game_engine.dart';
import 'package:monopoly/game/network/lan_game_codec.dart';
import 'package:monopoly/game/network/lan_room_controller.dart';
import 'package:monopoly/game/network/relay_host_transport.dart';

class _Hello {
  _Hello(this.socket, this.packet);
  final WebSocket socket;
  final Map<String, dynamic> packet;
}

/// Small, controllable host. Holding a state packet allows the tests to
/// distinguish transport connectivity from authenticated game synchronization.
class _TestHost {
  _TestHost(this.server, {this.relay = false}) {
    server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((raw) {
        final outer = jsonDecode(raw as String) as Map<String, dynamic>;
        if (relay && outer['kind'] == 'join') {
          socket.add(jsonEncode({'kind': 'joined', 'room': outer['room']}));
          return;
        }
        final packet = relay && outer['kind'] == 'to_host'
            ? jsonDecode(outer['payload'] as String) as Map<String, dynamic>
            : outer;
        if (packet['type'] == 'hello') {
          hellos.add(_Hello(socket, packet));
        } else if (packet['type'] == 'action') {
          actions.add(packet);
        }
      }, onError: (Object _) {});
    });
  }

  final HttpServer server;
  final bool relay;
  final List<WebSocket> sockets = [];
  final List<_Hello> hellos = [];
  final List<Map<String, dynamic>> actions = [];
  static const token = '0123456789abcdef0123456789abcdef0123456789abcdef';

  static Future<_TestHost> open({bool relay = false}) async => _TestHost(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    relay: relay,
  );

  Uri get endpoint => Uri(scheme: 'ws', host: '127.0.0.1', port: server.port);

  Future<_Hello> hello(int index) async {
    await _until(() => hellos.length > index);
    return hellos[index];
  }

  Future<LanRoomController> join() => relay
      ? LanRoomController.joinRelay(
          name: 'Bob',
          endpoint: endpoint,
          roomCode: 'ABCDEFGH',
        )
      : LanRoomController.join(
          name: 'Bob',
          hostIp: '127.0.0.1',
          pin: '123456',
          port: server.port,
        );

  void welcome(WebSocket socket) =>
      send(socket, {'type': 'welcome', 'id': 1, 'token': token});

  void room(WebSocket socket, {required bool started}) => send(socket, {
    'type': 'room',
    'started': started,
    'paused': false,
    'members': [
      {'id': 0, 'name': 'Alice', 'connected': true},
      {'id': 1, 'name': 'Bob', 'connected': true},
    ],
  });

  void state(WebSocket socket, GameEngine game, {bool invalid = false}) {
    final snapshot = LanGameCodec.encode(game);
    if (invalid) snapshot['properties'] = [];
    send(socket, {
      'type': 'state',
      'paused': false,
      'state': snapshot,
      'event': null,
      'pendingTrade': null,
    });
  }

  void send(WebSocket socket, Map<String, dynamic> packet) =>
      socket.add(jsonEncode(packet));

  Future<void> close() async {
    for (final socket in sockets) {
      try {
        await socket.close().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    await server.close(force: true);
  }
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 6));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Loopback condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _closeSocket(WebSocket socket) =>
    socket.close().then<void>((_) {});

void main() {
  test(
    'initial PIN rejection fails the join rather than exposing a false connected room',
    () async {
      final host = await _TestHost.open();
      try {
        final joining = host.join();
        final rejected = expectLater(joining, throwsStateError);
        final hello = await host.hello(0);
        host.send(hello.socket, {
          'type': 'error',
          'message': 'Incorrect room PIN or incompatible game version.',
        });
        await rejected;
      } finally {
        await host.close();
      }
    },
  );

  for (final relay in [false, true]) {
    test(
      '${relay ? 'relay' : 'Wi-Fi'} rejoin is single-flight and waits for valid host state',
      () async {
        final host = await _TestHost.open(relay: relay);
        LanRoomController? guest;
        try {
          final joining = host.join();
          final first = await host.hello(0);
          host.welcome(first.socket);
          host.room(first.socket, started: false);
          final joined = await joining;
          guest = joined;
          expect(joined.connected, isTrue);
          expect(joined.playerId, 1);
          final engine = GameEngine(
            playerNames: ['Alice', 'Bob'],
            cardSeed: 42,
          );
          host.welcome(first.socket);
          host.room(first.socket, started: true);
          host.state(first.socket, engine);
          await _until(() => joined.game != null);
          final oldBalance = joined.game!.players[1].balance;

          await _closeSocket(first.socket);
          await _until(() => !joined.connected);
          final rejoining = joined.reconnect();
          await joined.reconnect(); // Must not create a second transport.
          expect(joined.reconnecting, isTrue);
          final second = await host.hello(1);
          expect(second.packet['token'], _TestHost.token);
          host.welcome(second.socket);
          host.room(second.socket, started: true);
          await _until(() => !joined.paused);
          expect(joined.connected, isFalse);
          expect(joined.reconnecting, isTrue);
          await joined.sendAction('roll'); // Cannot be queued/replayed.

          engine.players[1].balance = oldBalance - 10;
          host.state(second.socket, engine);
          await rejoining;
          expect(joined.connected, isTrue);
          expect(joined.reconnecting, isFalse);
          expect(joined.game!.players[1].balance, oldBalance - 10);
          // A fresh explicit command is delivered; nothing pending was replayed.
          await joined.sendAction('endTurn');
          await _until(() => host.actions.isNotEmpty);
          expect(host.actions.map((e) => e['action']).toList(), ['endTurn']);
          expect(host.hellos.length, 2);
          expect(host.sockets.length, 2);
        } finally {
          await guest?.shutdown();
          await host.close();
        }
      },
    );
  }

  test(
    'malformed rejoin snapshot preserves previous board and rejects continuation',
    () async {
      final host = await _TestHost.open();
      LanRoomController? guest;
      try {
        final joining = host.join();
        final first = await host.hello(0);
        final engine = GameEngine(playerNames: ['Alice', 'Bob'], cardSeed: 42);
        host.welcome(first.socket);
        host.room(first.socket, started: true);
        host.state(first.socket, engine);
        final joined = await joining;
        guest = joined;
        final original = joined.game!;
        final balance = original.players[1].balance;
        await _closeSocket(first.socket);
        await _until(() => !joined.connected);
        final rejected = expectLater(joined.reconnect(), throwsStateError);
        final second = await host.hello(1);
        host.welcome(second.socket);
        host.room(second.socket, started: true);
        engine.players[1].balance = balance - 10;
        host.state(second.socket, engine, invalid: true);
        await rejected;
        expect(joined.connected, isFalse);
        expect(joined.reconnecting, isFalse);
        expect(joined.paused, isTrue);
        expect(identical(joined.game, original), isTrue);
        expect(original.players[1].balance, balance);
        expect(host.actions, isEmpty);
      } finally {
        await guest?.shutdown();
        await host.close();
      }
    },
  );

  test('relay host disconnect during startup is an awaited failure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {
        unawaited(_closeSocket(socket));
      });
    });
    final transport = RelayHostTransport(
      endpoint: Uri(scheme: 'ws', host: '127.0.0.1', port: server.port),
      code: 'ABCDEFGH',
      capacity: 2,
    );
    try {
      await expectLater(
        transport.start(onMessage: (_, _) {}, onDisconnect: (_) {}),
        throwsA(anyOf(isA<Exception>(), isA<StateError>())),
      );
    } finally {
      await transport.close();
      await server.close(force: true);
    }
  });
}
