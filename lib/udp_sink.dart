import 'dart:async';
import 'dart:typed_data';

import 'package:udp/udp.dart';

class UdpSink implements StreamSink<Uint8List> {
  final UDP _udpSocket;
  final void Function() _onDisconnect;
  final Endpoint _remoteEndpoint;

  UdpSink(this._udpSocket, this._remoteEndpoint, this._onDisconnect);

  @override
  void add(Uint8List data) {
    _udpSocket.send(data, _remoteEndpoint);
  }

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {
    _udpSocket.close();
    _onDisconnect();
  }

  @override
  Future<void> get done => Future.value();

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    print('Error in UdpSink: $error');
    _onDisconnect();
  }
}
