/// Implemented on Android / desktop only. Conditional import avoids dart:io
/// leaking into Flutter Web builds.
abstract class LanHostTransport {
  List<String> get addresses;

  Future<void> start({
    required void Function(Object connection, String message) onMessage,
    required void Function(Object connection) onDisconnect,
  });

  void send(Object connection, String message);
  Future<void> close();
}
