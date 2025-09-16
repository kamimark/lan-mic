import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lan_mic/home.dart';
import 'package:lan_mic/latency_chart.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LAN Mic',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const MyHomePage(title: 'LAN Microphone'),
    );
  }
}

enum AppError { noMicAccess, noWifi }

enum MicState { disconnected, discovering, connecting, connected }

const double mainButtonSize = 124;
const EdgeInsetsDirectional switchPadding = EdgeInsetsDirectional.fromSTEB(
  24,
  4,
  12,
  4,
);

final GlobalKey<LatencyChartState> latencyChartKey =
    GlobalKey<LatencyChartState>();

Future<String> getDeviceName() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  var info = await deviceInfo.deviceInfo;
  if (info is AndroidDeviceInfo) {
    return "${info.name} (${info.model})";
  } else if (info is IosDeviceInfo) {
    return "${info.name} (${info.model})";
  } else if (info is WindowsDeviceInfo) {
    return info.computerName;
  }
  return "Unknown";
}
