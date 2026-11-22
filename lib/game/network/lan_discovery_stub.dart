import 'lan_discovery.dart';

LanDiscoveryService createLanDiscoveryService() => _UnsupportedDiscovery();

class _UnsupportedDiscovery extends LanDiscoveryService {
  _UnsupportedDiscovery() : super.internal();
  @override
  List<LanDiscoveredRoom> get rooms => const <LanDiscoveredRoom>[];
  @override
  String? get lastError =>
      'Room scanning is not available in Web browsers. Use the host IP.';
  @override
  bool get isBrowsing => false;
  @override
  Future<void> startAdvertising(LanDiscoveryInfo info) async {}
  @override
  void updateAdvertisingCount(int playerCount) {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> startBrowsing({required int protocol}) async {}
  @override
  Future<void> stopBrowsing() async {}
  @override
  Future<void> close() async {
    dispose();
  }
}
