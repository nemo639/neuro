import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum TremorPhase { instructions, leftHand, rightHand, completed }

class RestingTremorTestScreen extends StatefulWidget {
  const RestingTremorTestScreen({super.key});

  @override
  State<RestingTremorTestScreen> createState() => _RestingTremorTestScreenState();
}

class _RestingTremorTestScreenState extends State<RestingTremorTestScreen>
    with TickerProviderStateMixin {
  TremorPhase _currentPhase = TremorPhase.instructions;

  late AnimationController _pulseController;

  // Test configuration
  final int _testDurationSeconds = 15;
  int _timeRemaining = 15;
  Timer? _testTimer;

  // Sensor data
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  final List<Map<String, double>> _accelSamples = [];
  final List<Map<String, double>> _gyroSamples = [];
  double _currentMagnitude = 0.0;

  // Results
  Map<String, dynamic> _leftHandResults = {};
  Map<String, dynamic> _rightHandResults = {};

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color tealAccent = Color(0xFF14B8A6);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _testTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    super.dispose();
  }

  void _startLeftHand() {
    setState(() {
      _currentPhase = TremorPhase.leftHand;
      _timeRemaining = _testDurationSeconds;
      _accelSamples.clear();
      _gyroSamples.clear();
      _currentMagnitude = 0.0;
    });
    _startSensors();
    _startTimer();
  }

  void _startRightHand() {
    setState(() {
      _currentPhase = TremorPhase.rightHand;
      _timeRemaining = _testDurationSeconds;
      _accelSamples.clear();
      _gyroSamples.clear();
      _currentMagnitude = 0.0;
    });
    _startSensors();
    _startTimer();
  }

  void _startSensors() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();

    _accelSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20), // 50Hz
    ).listen((event) {
      final t = DateTime.now().millisecondsSinceEpoch.toDouble();
      _accelSamples.add({'x': event.x, 'y': event.y, 'z': event.z, 't': t});
      setState(() {
        _currentMagnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z) - 9.81;
        _currentMagnitude = _currentMagnitude.abs();
      });
    });

    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      final t = DateTime.now().millisecondsSinceEpoch.toDouble();
      _gyroSamples.add({'x': event.x, 'y': event.y, 'z': event.z, 't': t});
    });
  }

  void _stopSensors() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
  }

  void _startTimer() {
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _stopSensors();
        _finishCurrentHand();
      }
    });
  }

  void _finishCurrentHand() {
    final results = _calculateResults();

    if (_currentPhase == TremorPhase.leftHand) {
      _leftHandResults = results;
      Future.delayed(const Duration(milliseconds: 1500), _startRightHand);
    } else {
      _rightHandResults = results;
      setState(() {
        _currentPhase = TremorPhase.completed;
      });
    }
  }

  Map<String, dynamic> _calculateResults() {
    if (_accelSamples.length < 10) {
      return {
        'sample_count': _accelSamples.length,
        'tremor_amplitude': 0.0,
        'tremor_frequency': 0.0,
        'rms_acceleration': 0.0,
        'peak_acceleration': 0.0,
        'jerk_mean': 0.0,
      };
    }

    // Calculate magnitude for each sample (remove gravity ~9.81)
    final magnitudes = _accelSamples.map((s) {
      final mag = math.sqrt(s['x']! * s['x']! + s['y']! * s['y']! + s['z']! * s['z']!) - 9.81;
      return mag.abs();
    }).toList();

    // RMS acceleration (root mean square)
    final rms = math.sqrt(
      magnitudes.map((m) => m * m).reduce((a, b) => a + b) / magnitudes.length,
    );

    // Peak acceleration
    final peak = magnitudes.reduce(math.max);

    // Mean amplitude (average absolute deviation from mean)
    final meanMag = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    final amplitude = magnitudes.map((m) => (m - meanMag).abs()).reduce((a, b) => a + b) / magnitudes.length;

    // Tremor frequency estimation via zero-crossing rate
    // PD resting tremor is typically 4-6 Hz
    final centered = magnitudes.map((m) => m - meanMag).toList();
    int zeroCrossings = 0;
    for (int i = 1; i < centered.length; i++) {
      if ((centered[i] >= 0 && centered[i - 1] < 0) ||
          (centered[i] < 0 && centered[i - 1] >= 0)) {
        zeroCrossings++;
      }
    }
    final durationSec = _testDurationSeconds.toDouble();
    final frequency = zeroCrossings / (2.0 * durationSec); // Hz

    // Jerk (rate of change of acceleration)
    double totalJerk = 0;
    for (int i = 1; i < magnitudes.length; i++) {
      final dt = 0.02; // 50Hz → 20ms
      totalJerk += ((magnitudes[i] - magnitudes[i - 1]) / dt).abs();
    }
    final jerkMean = totalJerk / (magnitudes.length - 1);

    // Gyroscope RMS (rotational tremor)
    double gyroRms = 0;
    if (_gyroSamples.isNotEmpty) {
      final gyroMags = _gyroSamples.map((s) {
        return math.sqrt(s['x']! * s['x']! + s['y']! * s['y']! + s['z']! * s['z']!);
      }).toList();
      gyroRms = math.sqrt(
        gyroMags.map((m) => m * m).reduce((a, b) => a + b) / gyroMags.length,
      );
    }

    return {
      'sample_count': _accelSamples.length,
      'duration_seconds': durationSec,
      'tremor_amplitude': double.parse(amplitude.toStringAsFixed(4)),
      'tremor_frequency': double.parse(frequency.toStringAsFixed(2)),
      'rms_acceleration': double.parse(rms.toStringAsFixed(4)),
      'peak_acceleration': double.parse(peak.toStringAsFixed(4)),
      'jerk_mean': double.parse(jerkMean.toStringAsFixed(4)),
      'gyro_rms': double.parse(gyroRms.toStringAsFixed(4)),
    };
  }

  Map<String, dynamic> _getTestData() {
    final leftAmp = (_leftHandResults['tremor_amplitude'] ?? 0.0) as double;
    final rightAmp = (_rightHandResults['tremor_amplitude'] ?? 0.0) as double;
    final asymmetry = (leftAmp + rightAmp) > 0
        ? ((rightAmp - leftAmp).abs() / ((rightAmp + leftAmp) / 2) * 100)
        : 0.0;

    return {
      'test_type': 'resting_tremor',
      'test_duration_seconds': _testDurationSeconds,
      'left_hand': _leftHandResults,
      'right_hand': _rightHandResults,
      'asymmetry_index': double.parse(asymmetry.toStringAsFixed(1)),
      'completed': true,
    };
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _testTimer?.cancel();
    _stopSensors();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitTest,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resting Tremor',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildPhaseIndicator(),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    Color color;
    String text;
    IconData icon;

    switch (_currentPhase) {
      case TremorPhase.instructions:
        color = tealAccent;
        text = 'Ready';
        icon = Icons.vibration_rounded;
        break;
      case TremorPhase.leftHand:
        color = blueAccent;
        text = 'Left';
        icon = Icons.back_hand_rounded;
        break;
      case TremorPhase.rightHand:
        color = purpleAccent;
        text = 'Right';
        icon = Icons.front_hand_rounded;
        break;
      case TremorPhase.completed:
        color = greenAccent;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case TremorPhase.instructions:
        return 'Read instructions carefully';
      case TremorPhase.leftHand:
        return 'Hold phone still in left hand';
      case TremorPhase.rightHand:
        return 'Hold phone still in right hand';
      case TremorPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar() {
    double progress = 0;
    switch (_currentPhase) {
      case TremorPhase.instructions:
        progress = 0;
        break;
      case TremorPhase.leftHand:
        progress = 0.1 + (1 - _timeRemaining / _testDurationSeconds) * 0.4;
        break;
      case TremorPhase.rightHand:
        progress = 0.5 + (1 - _timeRemaining / _testDurationSeconds) * 0.4;
        break;
      case TremorPhase.completed:
        progress = 1.0;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [tealAccent, blueAccent]),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildPhaseContent(),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case TremorPhase.instructions:
        return _buildInstructionsPhase();
      case TremorPhase.leftHand:
      case TremorPhase.rightHand:
        return _buildRecordingPhase();
      case TremorPhase.completed:
        return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.vibration_rounded, color: tealAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Resting Tremor Test',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Detect hand tremor using phone sensors',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.phone_android, 'Hold the phone flat on your open palm'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.airline_seat_recline_normal, 'Sit comfortably with arm resting on your lap'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.do_not_touch, 'Do NOT grip the phone — let it rest naturally'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.timer, '15 seconds per hand'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.back_hand, 'Left hand first, then right hand'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The phone sensors will measure involuntary tremor. Stay as still as possible.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHandChip('Left', blueAccent, Icons.back_hand_rounded),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 20),
              const SizedBox(width: 10),
              _buildHandChip('Right', purpleAccent, Icons.front_hand_rounded),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startLeftHand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: tealAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: tealAccent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Start Test',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
      ],
    );
  }

  Widget _buildHandChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRecordingPhase() {
    final isLeft = _currentPhase == TremorPhase.leftHand;
    final color = isLeft ? blueAccent : purpleAccent;
    final handText = isLeft ? 'LEFT HAND' : 'RIGHT HAND';

    // Map tremor magnitude to visual intensity (0-1 scale)
    final intensity = (_currentMagnitude / 2.0).clamp(0.0, 1.0);
    final intensityColor = Color.lerp(greenAccent, redAccent, intensity)!;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isLeft ? Icons.back_hand_rounded : Icons.front_hand_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                handText,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Timer
        Text(
          '$_timeRemaining',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w300,
            color: _timeRemaining <= 3 ? redAccent : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'seconds remaining',
          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
        ),
        const SizedBox(height: 30),
        // Live tremor indicator
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseSize = 120.0 + (intensity * 40) + (_pulseController.value * 10);
            return Container(
              width: pulseSize,
              height: pulseSize,
              decoration: BoxDecoration(
                color: intensityColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: intensityColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: intensityColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: intensityColor.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.vibration_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        // Live reading
        Text(
          '${_currentMagnitude.toStringAsFixed(3)} m/s\u00B2',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: intensityColor),
        ),
        Text(
          _currentMagnitude < 0.3 ? 'Stable' : _currentMagnitude < 1.0 ? 'Mild tremor' : 'Significant tremor',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const Spacer(),
        Text(
          'Hold phone flat on your open palm',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCompletedPhase() {
    final leftAmp = (_leftHandResults['tremor_amplitude'] ?? 0.0) as double;
    final rightAmp = (_rightHandResults['tremor_amplitude'] ?? 0.0) as double;
    final leftFreq = (_leftHandResults['tremor_frequency'] ?? 0.0) as double;
    final rightFreq = (_rightHandResults['tremor_frequency'] ?? 0.0) as double;
    final asymmetry = _getTestData()['asymmetry_index'] as double;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: greenAccent, size: 45),
          ),
          const SizedBox(height: 20),
          const Text(
            'Test Completed!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildHandResultCard('Left Hand', leftAmp, leftFreq, blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildHandResultCard('Right Hand', rightAmp, rightFreq, purpleAccent)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Asymmetry Index', style: TextStyle(fontSize: 14)),
                Text('${asymmetry.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getTremorInterpretation(leftAmp, rightAmp, leftFreq, rightFreq),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Continue', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandResultCard(String title, double amplitude, double frequency, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(amplitude.toStringAsFixed(3),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text('amplitude', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text('${frequency.toStringAsFixed(1)} Hz',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          Text('frequency', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _getTremorInterpretation(double leftAmp, double rightAmp, double leftFreq, double rightFreq) {
    final maxAmp = math.max(leftAmp, rightAmp);
    final avgFreq = (leftFreq + rightFreq) / 2;

    if (maxAmp < 0.1) {
      return 'Minimal tremor detected. Results within normal range.';
    } else if (maxAmp < 0.5) {
      if (avgFreq >= 4 && avgFreq <= 7) {
        return 'Mild tremor at ${avgFreq.toStringAsFixed(1)}Hz (PD-characteristic range: 4-6Hz). Further clinical evaluation recommended.';
      }
      return 'Mild tremor detected. Frequency outside typical PD range.';
    } else {
      if (avgFreq >= 4 && avgFreq <= 7) {
        return 'Notable tremor at ${avgFreq.toStringAsFixed(1)}Hz in PD-characteristic range. Clinical evaluation recommended.';
      }
      return 'Notable tremor detected at ${avgFreq.toStringAsFixed(1)}Hz. Clinical evaluation recommended.';
    }
  }
}
