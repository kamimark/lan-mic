import 'package:flutter/material.dart';
import 'package:lan_mic/latency_chart.dart';
import 'package:lan_mic/main.dart';
import 'package:lan_mic/recorder.dart';
import 'package:lan_mic/search_discovery.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:record/record.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final ServerDiscovery _serverDiscovery = ServerDiscovery();
  final Recorder _recorder = Recorder();
  final _record = AudioRecorder();

  MicState? _micState;
  AppError? _appError;

  String _deviceName = "N/A";
  int? ping;
  bool useVoiceProcessing = false;
  bool runInBackground = false;
  String? _version;

  Future<bool> requestMicrophonePermission() async {
    bool hasPermission = await _record.hasPermission();

    return hasPermission;
  }

  void toggleConnect() async {
    if (_micState == null) return;
    if (_micState != MicState.disconnected) {
      _serverDiscovery.stopDiscovery();
      stop();
    } else {
      start();
    }
  }

  void stop() {
    _serverDiscovery.stopDiscovery();
    _recorder.stopRecorder();
    latencyChartKey.currentState?.stopPing();
    setState(() {
      if (_micState != null) _micState = MicState.disconnected;
    });
  }

  Future start() async {
    setState(() {
      _micState = MicState.discovering;
    });

    _deviceName = await getDeviceName();
    var serverDetails = await _serverDiscovery.discoverServerDetails(
      _deviceName,
    );
    if (serverDetails == null) {
      setState(() {
        _micState = MicState.disconnected;
      });
      return;
    }

    setState(() {
      _micState = MicState.connecting;
    });

    var ready = await _recorder.startRecorder(
      serverDetails,
      useVoiceProcessing,
      stop,
    );

    if (!ready) {
      setState(() {
        _micState = MicState.disconnected;
      });
    } else {
      setState(() {
        _micState = MicState.connected;
        latencyChartKey.currentState?.startPing(
          serverDetails.address,
          serverDetails.echoPort,
        );
      });
    }
  }

  Widget getConnectionIcon() {
    switch (_micState) {
      case null:
      case MicState.disconnected:
        return Icon(Icons.mic_off_outlined);
      case MicState.discovering:
      case MicState.connecting:
        return Center(
          child: SizedBox(
            width: mainButtonSize,
            height: mainButtonSize,
            child: CircularProgressIndicator(
              strokeWidth: 32,
              color: Colors.white,
            ),
          ),
        );
      case MicState.connected:
        return Icon(Icons.mic_outlined);
    }
  }

  String getConnectionText() {
    switch (_appError) {
      case null:
        break;
      case AppError.noMicAccess:
        return "Please give microphone access to the app";
      case AppError.noWifi:
        return "Please turn your WI-FI on and connect to LAN";
    }

    switch (_micState) {
      case null:
        return "Not ready";
      case MicState.disconnected:
        return "Tap to connect";
      case MicState.discovering:
        return "Scanning for server";
      case MicState.connecting:
        return "Connecting on server";
      case MicState.connected:
        return "Mic is currently shared to LAN";
    }
  }

  Color getConnectionColor() {
    switch (_micState) {
      case null:
        return Colors.grey.shade500;
      case MicState.disconnected:
        return Colors.red.shade500;
      case MicState.discovering:
        return Colors.orange.shade500;
      case MicState.connecting:
        return Colors.lightGreen.shade500;
      case MicState.connected:
        return Colors.green.shade500;
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(checkState);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.stopRecorder();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      checkState(null);
    } else if (!runInBackground) {
      stop();
    }
  }

  Future checkState(_) async {
    _version ??= (await PackageInfo.fromPlatform()).version;

    var ip = await _serverDiscovery.detectNetwork();
    if (ip == null) {
      setState(() {
        _appError = AppError.noWifi;
        _micState = null;
      });
      return;
    }

    bool hasMicPermission = await requestMicrophonePermission();
    if (!hasMicPermission) {
      setState(() {
        _appError = AppError.noMicAccess;
        _micState = null;
      });
      return;
    }

    setState(() {
      _appError = null;
      _micState ??= MicState.disconnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text("${widget.title} ${_version ?? ""}"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: ScrollController(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Center(
                child: Padding(
                  padding: EdgeInsetsGeometry.directional(top: 32),
                  child: AnimatedOpacity(
                    duration: Durations.medium4,
                    opacity: _micState == null ? 0 : 1,
                    child: Text(
                      "Name: $_deviceName",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsetsGeometry.directional(bottom: 32),
                  child: AnimatedOpacity(
                    duration: Durations.medium4,
                    opacity: _micState == null ? 0 : 1,
                    child: Text(
                      "IP: ${_serverDiscovery.wifiIp ?? "N/A"}",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
              SwitchListTile(
                title: _recorder.useUdp
                    ? Text(
                        "UDP",
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    : Text(
                        "TCP",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                contentPadding: switchPadding,
                value: _recorder.useUdp,
                onChanged: _micState == MicState.disconnected
                    ? (_) =>
                          setState(() => _recorder.useUdp = !_recorder.useUdp)
                    : null,
              ),
              SwitchListTile(
                title: useVoiceProcessing
                    ? Text(
                        "Voice Processing",
                        style: Theme.of(context).textTheme.titleLarge,
                      )
                    : Text(
                        "No Voice Processing",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                contentPadding: switchPadding,
                value: useVoiceProcessing,
                onChanged: _micState == MicState.disconnected
                    ? (_) => setState(
                        () => useVoiceProcessing = !useVoiceProcessing,
                      )
                    : null,
              ),
              SwitchListTile(
                title: Text(
                  "Run in background",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                contentPadding: switchPadding,
                value: runInBackground,
                onChanged: (_) =>
                    setState(() => runInBackground = !runInBackground),
              ),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(vertical: 32),
                child: IconButton(
                  iconSize: mainButtonSize,
                  onPressed: _micState == null ? null : toggleConnect,
                  icon: getConnectionIcon(),
                  style: IconButton.styleFrom(
                    backgroundColor: getConnectionColor(),
                    foregroundColor: Colors.white,
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(32),
                  ),
                ),
              ),
              Text(
                getConnectionText(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Center(
                child: Padding(
                  padding: EdgeInsetsGeometry.symmetric(vertical: 32),
                  child: AnimatedOpacity(
                    duration: Durations.medium4,
                    opacity: ping == null ? 0 : 1,
                    child: Text(
                      "Ping: ${ping ?? "N/A"} ms",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 32),
                child: LatencyChart(key: latencyChartKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
