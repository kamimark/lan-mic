import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:lan_mic/search_discovery.dart';
import 'package:lan_mic/socket_sink.dart';
import 'package:lan_mic/udp_sink.dart';
import 'package:udp/udp.dart';

class Recorder {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  Socket? _socket;
  UDP? _udpSocket;
  bool _connecting = false;
  bool useUdp = true;
  void Function()? _stop;

  Future stopRecorder() async {
    _connecting = false;
    await _recorder.stopRecorder();
    _socket?.destroy();
    _udpSocket?.close();
    _socket = null;
    _udpSocket = null;
  }

  Future<bool> startRecorder(
    ServerDetails serverDetails,
    bool useVoiceProcessing,
    void Function() stop,
  ) async {
    _stop = stop;
    return await (useUdp
        ? startTcpRecorder(serverDetails, useVoiceProcessing)
        : startUdpRecorder(serverDetails, useVoiceProcessing));
  }

  Future<bool> startTcpRecorder(
    ServerDetails serverDetails,
    bool useVoiceProcessing,
  ) async {
    _connecting = true;
    while (_connecting) {
      try {
        _socket = await Socket.connect(
          serverDetails.address,
          serverDetails.voicePort.value,
          timeout: Duration(seconds: 1),
        );
        if (_connecting == false) {
          _socket?.destroy();
          return false;
        }
        if (_socket == null) throw Exception("Timeout?");
        break;
      } catch (e) {
        print(e);
      }
    }
    _connecting = false;

    await _recorder.openRecorder();
    await _recorder.startRecorder(
      toStream: SocketSink(_socket!, socketDied),
      bitRate: 16000,
      numChannels: 1,
      codec: Codec.pcm16,
      enableVoiceProcessing: useVoiceProcessing,
    );

    return true;
  }

  Future<bool> startUdpRecorder(
    ServerDetails serverDetails,
    bool useVoiceProcessing,
  ) async {
    _connecting = true;
    _udpSocket = await UDP.bind(Endpoint.any());
    _connecting = false;

    var endPoint = Endpoint.unicast(
      serverDetails.address,
      port: serverDetails.voicePort,
    );

    await _recorder.openRecorder();
    await _recorder.startRecorder(
      toStream: UdpSink(_udpSocket!, endPoint, socketDied),
      bitRate: 16000,
      numChannels: 1,
      codec: Codec.pcm16,
      enableVoiceProcessing: useVoiceProcessing,
    );

    return true;
  }

  void socketDied() async {
    await _recorder.stopRecorder();
    _socket = null;
    _udpSocket = null;
    if (_stop != null) _stop!();
  }
}
