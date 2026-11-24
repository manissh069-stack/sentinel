import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() => runApp(const SentinelApp());

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentinel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5A0),
          brightness: Brightness.dark,
        ),
      ),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  StreamSubscription<MagnetometerEvent>? _magSub;
  double _x = 0, _y = 0, _z = 0;
  double _fieldStrength = 0;
  double _baseline = 0;
  double _peakDeviation = 0;
  bool _baselineSet = false;
  bool _scanning = false;
  String _verdict = 'Tap START and hold still for 2 seconds.';

  final List<double> _baselineSamples = [];
  static const int _baselineCount = 20;
  static const double _threshold = 15.0;

  void _startScan() {
    _baselineSamples.clear();
    _baselineSet = false;
    _scanning = true;
    _peakDeviation = 0;
    _verdict = 'Hold still. Capturing baseline...';

    _magSub = magnetometerEventStream().listen((MagnetometerEvent e) {
      final strength = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      setState(() {
        _x = e.x;
        _y = e.y;
        _z = e.z;
        _fieldStrength = strength;
      });

      if (!_baselineSet) {
        _baselineSamples.add(strength);
        if (_baselineSamples.length >= _baselineCount) {
          _baseline =
              _baselineSamples.reduce((a, b) => a + b) / _baselineCount;
          _baselineSet = true;
          setState(() {
            _verdict =
                'Baseline: ${_baseline.toStringAsFixed(1)} µT. Move around now.';
          });
        }
        return;
      }

      final deviation = (strength - _baseline).abs();
      if (deviation > _peakDeviation) _peakDeviation = deviation;

      if (deviation > _threshold) {
        setState(() {
          _verdict =
              '⚠ ANOMALY: ${deviation.toStringAsFixed(1)} µT above baseline.';
        });
      } else if (deviation > _threshold * 0.5) {
        setState(() => _verdict =
            'Elevated field (${deviation.toStringAsFixed(1)} µT). Keep moving.');
      } else {
        setState(() => _verdict = 'Normal field. Scanning...');
      }
    });
  }

  void _stopScan() {
    _magSub?.cancel();
    _magSub = null;
    setState(() {
      _scanning = false;
      _verdict =
          'Scan stopped. Peak: ${_peakDeviation.toStringAsFixed(1)} µT';
    });
  }

  @override
  void dispose() {
    _magSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviation = _baselineSet ? (_fieldStrength - _baseline) : 0.0;
    final risk =
        _baselineSet ? (deviation.abs() / _threshold).clamp(0.0, 1.0) : 0.0;
    final riskColor = risk > 0.7
        ? Colors.redAccent
        : risk > 0.4
            ? Colors.orangeAccent
            : const Color(0xFF00E5A0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTINEL'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text('SHARK SENSE — Magnetic Scanner',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            Text('${_fieldStrength.toStringAsFixed(1)} µT',
                style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: riskColor)),
            Text(
              _baselineSet
                  ? 'Baseline: ${_baseline.toStringAsFixed(1)} µT'
                  : 'No baseline yet',
              style: TextStyle(
                  color: _baselineSet ? Colors.greenAccent : Colors.grey),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: risk,
                minHeight: 20,
                backgroundColor: Colors.grey[850],
                valueColor: AlwaysStoppedAnimation(riskColor),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_axis('X', _x), _axis('Y', _y), _axis('Z', _z)],
            ),
            const SizedBox(height: 24),
            Card(
              color: riskColor.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: riskColor, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_verdict, style: const TextStyle(fontSize: 15)),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanning ? _stopScan : _startScan,
                icon: Icon(_scanning ? Icons.stop : Icons.play_arrow),
                label: Text(_scanning ? 'STOP' : 'START SCAN',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: _scanning ? Colors.redAccent : riskColor,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Hold near a webcam, router, or TV to test.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _axis(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value.toStringAsFixed(1)),
      ],
    );
  }
}