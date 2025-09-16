import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:udp/udp.dart';

class WifiNotEnabledException implements Exception {
  final String message;
  WifiNotEnabledException([this.message = 'Wi-Fi is not enabled.']);

  @override
  String toString() => 'WifiNotEnabledException: $message';
}

class ServerDetails {
  InternetAddress address;
  Port voicePort;
  Port echoPort;
  ServerDetails(this.address, this.voicePort, this.echoPort);
}

class ServerDiscovery {
  static const int discoveryPort = 50763;
  static const String discoveryMessage = "LANMIC_CLIENT_DISCOVERY";
  static const String discoveryResponse = "LANMIC_SERVER_RESPONSE-";
  final NetworkInfo _networkInfo = NetworkInfo();

  bool _running = false;
  String? wifiIp = "";

  void stopDiscovery() async {
    _running = false;
  }

  Future detectNetwork() async {
    wifiIp = await _networkInfo.getWifiIP();
    while (wifiIp == null) {
      if (!_running) break;
      await Future.delayed(Duration(seconds: 1));
      wifiIp = await _networkInfo.getWifiIP();
    }
    return wifiIp;
  }

  Future<ServerDetails?> discoverServerDetails(String deviceName) async {
    _running = true;
    wifiIp = await detectNetwork();
    if (wifiIp == null) return null;
    var wifiIP = wifiIp!;

    final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));

    final completer = Completer<String?>();

    final sender = await UDP.bind(Endpoint.any());
    final receiver = await UDP.bind(
      Endpoint.any(port: Port(sender.socket!.port)),
    );

    receiver.asStream().listen((datagram) {
      if (datagram != null) {
        final message = String.fromCharCodes(datagram.data);
        if (message.startsWith(discoveryResponse)) {
          final serverIp = datagram.address.address;
          if (!completer.isCompleted) {
            var details = message.substring(discoveryResponse.length);
            completer.complete("$serverIp:$details");
          }
        }
      }
    });

    _broadcastToSubnet(sender, subnet, deviceName);

    Timer.periodic(Duration(milliseconds: 1000), (timer) {
      if (!completer.isCompleted) {
        if (!_running) {
          completer.complete(null);
        } else {
          _broadcastToSubnet(sender, subnet, deviceName);
        }
      } else {
        timer.cancel();
      }
    });

    final result = await completer.future;

    receiver.close();
    sender.close();
    _running = false;

    var details = result!.split(":");
    var ports = details[1].split("-");
    return ServerDetails(InternetAddress(details[0]), Port(int.parse(ports[0])), Port(int.parse(ports[1])));
  }

  void _broadcastToSubnet(UDP sender, String subnet, String deviceName) async {
    final broadcastAddresses = [
      '255.255.255.255', // Global broadcast
      '$subnet.255', // Subnet broadcast
    ];

    for (final address in broadcastAddresses) {
      try {
        var msg = "$discoveryMessage-$deviceName";
        await sender.send(
          msg.codeUnits,
          Endpoint.broadcast(port: Port(discoveryPort)),
        );
        print('Sending to $address: $msg');
      } catch (e) {
        print('Error broadcasting to $address: $e');
      }
    }
  }
}
