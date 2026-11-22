import 'lan_host_transport.dart';
import 'lan_host_stub.dart'
    if (dart.library.io) 'lan_host_native.dart'
    as implementation;

LanHostTransport createLanHostTransport(int port) =>
    implementation.createLanHostTransport(port);
