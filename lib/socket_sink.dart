import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class SocketSink implements StreamSink<Uint8List> {
  final Socket _socket;
  final void Function() _onDisconnect;

  SocketSink(this._socket, this._onDisconnect);

  @override
  void add(Uint8List data) {
    _socket.add(data); // send mic data to server
  }

  @override
  Future<void> addStream(Stream<Uint8List> stream) {
    return _socket.addStream(stream);
  }

  @override
  Future<void> close() async {
    await _socket.flush();
    _onDisconnect();
  }

  @override
  Future<void> get done => _socket.done;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    print('Error in SocketSink: $error');
    _onDisconnect();
  }
}
