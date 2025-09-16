import 'dart:async';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:udp/udp.dart';

class LatencyChart extends StatefulWidget {
  final Duration pingInterval = const Duration(seconds: 1);
  final Duration displayDuration = const Duration(seconds: 30);

  const LatencyChart({super.key});

  @override
  LatencyChartState createState() => LatencyChartState();
}

class LatencyChartState extends State<LatencyChart> {
  final List<_LatencyPoint> _points = [];
  Timer? _timer;
  InternetAddress? _targetAddress;
  UDP? _sender;
  UDP? _receiver;
  int _lastSequenceNo = 0;
  int? _averagePing;

  void startPing(InternetAddress targetAddress, Port port) async {
    _timer?.cancel();

    _sender ??= await UDP.bind(Endpoint.any());
    final sender = _sender!;

    _receiver ??= await UDP.bind(Endpoint.any(port: Port(sender.socket!.port)));
    final receiver = _receiver!;

    var serverEndpoint = Endpoint.unicast(
      targetAddress,
      port: port,
    );

    receiver.asStream().listen((datagram) {
      if (datagram == null) {
        return;
      }

      final message = String.fromCharCodes(datagram.data);
      final parts = message.split("-");
      if (parts.length != 2) return;

      final seq = int.parse(parts[0]);
      if (seq != _lastSequenceNo) return;

      final since = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));

      setState(() {
        final now = DateTime.now();
        final duration = now.difference(since);
        _points.add(
          _LatencyPoint(time: now, latencyMs: duration.inMilliseconds),
        );
        _averagePing =
            (_points.map((e) => e.latencyMs).reduce((x, y) => x + y) /
                    _points.length)
                .round();
        _points.removeWhere(
          (point) => now.difference(point.time) > widget.displayDuration,
        );
      });
    });

    setState(() {
      _targetAddress = targetAddress;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (_) async {
      try {
        var msg =
            "${++_lastSequenceNo}-${DateTime.now().millisecondsSinceEpoch}";
        await sender.send(msg.codeUnits, serverEndpoint);
      } catch (e) {
        print('Error during ping: $e');
      }
    });
  }

  void stopPing() async {
    _timer?.cancel();
    setState(() {
      _targetAddress = null;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) {
      _points.add(_LatencyPoint(time: DateTime.now(), latencyMs: 0));
    }

    // Prepare data for the chart
    final now = DateTime.now();
    final minTime = now.subtract(widget.displayDuration);

    List<FlSpot> spots = _points
        .map(
          (p) => FlSpot(
            p.time.difference(minTime).inMilliseconds.toDouble() /
                1000, // x in seconds
            p.latencyMs < 0
                ? 0
                : p.latencyMs.toDouble(), // y latency (0 if failed)
          ),
        )
        .toList();

    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    maxY = (maxY * 1.2).clamp(
      100,
      double.infinity,
    ); // Add 20% headroom min 100ms

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text("Pinging ${_targetAddress ?? "N/A"}"),
            Expanded(
              child: Text(
                _averagePing == null ? "" : "${_averagePing}ms",
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Text(
                _points.isEmpty ? "" : "${_points.last.latencyMs}ms",
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 100,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: widget.displayDuration.inSeconds.toDouble(),
              minY: 0,
              maxY: maxY,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  barWidth: 2,
                  color: Colors.blue,
                  dotData: FlDotData(show: false),
                ),
              ],
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _LatencyPoint {
  final DateTime time;
  final int latencyMs; // -1 = failed ping

  _LatencyPoint({required this.time, required this.latencyMs});
}
