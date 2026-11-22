import 'lan_host_transport.dart';

LanHostTransport createLanHostTransport(int port) => _UnsupportedHost();

class _UnsupportedHost implements LanHostTransport {
  @override
  List<String> get addresses => const <String>[];

  @override
  Future<void> start({
    required void Function(Object, String) onMessage,
    required void Function(Object) onDisconnect,
  }) async {
    throw UnsupportedError('LAN hosting requires Android or a desktop OS.');
  }

  @override
  void send(Object connection, String message) {}

  @override
  Future<void> close() async {}
}
