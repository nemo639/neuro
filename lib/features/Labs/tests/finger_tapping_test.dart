import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/responsive.dart';

// Test phases
enum TappingPhase { instructions, leftHand, rightHand, completed }

class FingerTappingTestScreen extends StatefulWidget {
  const FingerTappingTestScreen({super.key});

  @override
  State<FingerTappingTestScreen> createState() => _FingerTappingTestScreenState();
}

class _FingerTappingTestScreenState extends State<FingerTappingTestScreen>
    with TickerProviderStateMixin {

  TappingPhase _currentPhase = TappingPhase.instructions;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rippleController;

  // Test configuration
  final int _testDurationSeconds = 10; // 10 seconds per hand
  int _timeRemaining = 10;
  Timer? _testTimer;

  // Tap tracking
  int _tapCount = 0;
  List<int> _tapTimestamps = [];
  DateTime? _lastTapTime;

  // Results
  Map<String, dynamic> _leftHandResults = {};
  Map<String, dynamic> _rightHandResults = {};

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color purpleAccent = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

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
    _rippleController.dispose();
    _testTimer?.cancel();
    super.dispose();
  }

  void _startLeftHand() {
    setState(() {
      _currentPhase = TappingPhase.leftHand;
      _tapCount = 0;
      _tapTimestamps = [];
      _timeRemaining = _testDurationSeconds;
    });
    _startTimer();
  }

  void _startRightHand() {
    setState(() {
      _currentPhase = TappingPhase.rightHand;
      _tapCount = 0;
      _tapTimestamps = [];
      _timeRemaining = _testDurationSeconds;
    });
    _startTimer();
  }

  void _startTimer() {
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _finishCurrentHand();
      }
    });
  }

  void _handleTap() {
    if (_timeRemaining <= 0) return;

    HapticFeedback.lightImpact();
    _rippleController.forward(from: 0);

    final now = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _tapCount++;
      _tapTimestamps.add(now);
      _lastTapTime = DateTime.now();
    });
  }

  void _finishCurrentHand() {
    final results = _calculateResults();

    if (_currentPhase == TappingPhase.leftHand) {
      _leftHandResults = results;
      // Short delay then start right hand
      Future.delayed(const Duration(milliseconds: 1500), _startRightHand);
    } else {
      _rightHandResults = results;
      setState(() {
        _currentPhase = TappingPhase.completed;
      });
    }
  }

  Map<String, dynamic> _calculateResults() {
    if (_tapTimestamps.length < 2) {
      return {
        'tap_count': _tapCount,
        'taps_per_second': _tapCount / _testDurationSeconds,
        'avg_interval_ms': 0,
        'interval_variability': 0,
        'timestamps': _tapTimestamps,
      };
    }

    // Calculate intervals between taps
    List<int> intervals = [];
    for (int i = 1; i < _tapTimestamps.length; i++) {
      intervals.add(_tapTimestamps[i] - _tapTimestamps[i - 1]);
    }

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;

    // Calculate variability (standard deviation)
    double sumSquares = 0;
    for (var interval in intervals) {
      sumSquares += math.pow(interval - avgInterval, 2);
    }
    final variability = math.sqrt(sumSquares / intervals.length);

    return {
      'tap_count': _tapCount,
      'taps_per_second': _tapCount / _testDurationSeconds,
      'avg_interval_ms': avgInterval,
      'interval_variability': variability,
      'intervals': intervals,
      'timestamps': _tapTimestamps,
    };
  }

  Map<String, dynamic> _getTestData() {
    return {
      'test_type': 'finger_tapping',
      'test_duration_seconds': _testDurationSeconds,
      'left_hand': _leftHandResults,
      'right_hand': _rightHandResults,
      'asymmetry_index': _calculateAsymmetry(),
      'completed': true,
    };
  }

  double _calculateAsymmetry() {
    final leftTaps = _leftHandResults['tap_count'] ?? 0;
    final rightTaps = _rightHandResults['tap_count'] ?? 0;
    if (leftTaps + rightTaps == 0) return 0;
    return (rightTaps - leftTaps).abs() / ((rightTaps + leftTaps) / 2) * 100;
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _testTimer?.cancel();
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
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(r),
            _buildProgressBar(r),
            Expanded(child: _buildContent(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(16)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitTest,
            child: Container(
              width: r.dp(44),
              height: r.dp(44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.dp(14)),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: r.dp(18)),
            ),
          ),
          SizedBox(width: r.w(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finger Tapping',
                  style: TextStyle(fontSize: r.sp(20), fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildHandIndicator(r),
        ],
      ),
    );
  }

  Widget _buildHandIndicator(Responsive r) {
    Color color;
    String text;
    IconData icon;

    switch (_currentPhase) {
      case TappingPhase.instructions:
        color = orangeAccent;
        text = 'Ready';
        icon = Icons.touch_app_rounded;
        break;
      case TappingPhase.leftHand:
        color = blueAccent;
        text = 'Left';
        icon = Icons.back_hand_rounded;
        break;
      case TappingPhase.rightHand:
        color = purpleAccent;
        text = 'Right';
        icon = Icons.front_hand_rounded;
        break;
      case TappingPhase.completed:
        color = greenAccent;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(6)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.dp(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: r.dp(16)),
          SizedBox(width: r.w(6)),
          Text(
            text,
            style: TextStyle(color: color, fontSize: r.sp(12), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case TappingPhase.instructions:
        return 'Read instructions carefully';
      case TappingPhase.leftHand:
        return 'Tap as fast as you can!';
      case TappingPhase.rightHand:
        return 'Tap as fast as you can!';
      case TappingPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    double progress = 0;
    switch (_currentPhase) {
      case TappingPhase.instructions:
        progress = 0;
        break;
      case TappingPhase.leftHand:
        progress = 0.1 + (1 - _timeRemaining / _testDurationSeconds) * 0.4;
        break;
      case TappingPhase.rightHand:
        progress = 0.5 + (1 - _timeRemaining / _testDurationSeconds) * 0.4;
        break;
      case TappingPhase.completed:
        progress = 1.0;
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.w(20)),
      height: r.h(6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(r.dp(3)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [orangeAccent, redAccent]),
            borderRadius: BorderRadius.circular(r.dp(3)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Responsive r) {
    return Container(
      margin: EdgeInsets.all(r.dp(20)),
      padding: EdgeInsets.all(r.dp(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.dp(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildPhaseContent(r),
    );
  }

  Widget _buildPhaseContent(Responsive r) {
    switch (_currentPhase) {
      case TappingPhase.instructions:
        return _buildInstructionsPhase(r);
      case TappingPhase.leftHand:
      case TappingPhase.rightHand:
        return _buildTappingPhase(r);
      case TappingPhase.completed:
        return _buildCompletedPhase(r);
    }
  }

  Widget _buildInstructionsPhase(Responsive r) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: r.h(10)),
          Container(
            width: r.dp(80),
            height: r.dp(80),
            decoration: BoxDecoration(
              color: orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.touch_app_rounded, color: orangeAccent, size: r.dp(40)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Finger Tapping Test',
            style: TextStyle(fontSize: r.sp(24), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Measure your motor speed and rhythm',
            style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
          ),
          SizedBox(height: r.h(24)),
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(r.dp(14)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.touch_app, 'Tap the circle as fast as possible', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.timer, '10 seconds per hand', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.back_hand, 'Left hand first, then right hand', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.speed, 'Keep a steady rhythm', r),
              ],
            ),
          ),
          SizedBox(height: r.h(20)),
          // Hand order indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHandChip('Left', blueAccent, Icons.back_hand_rounded, true, r),
              SizedBox(width: r.w(10)),
              Icon(Icons.arrow_forward, color: Colors.grey, size: r.dp(20)),
              SizedBox(width: r.w(10)),
              _buildHandChip('Right', purpleAccent, Icons.front_hand_rounded, false, r),
            ],
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _startLeftHand,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: orangeAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: orangeAccent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: r.dp(22)),
                  SizedBox(width: r.w(8)),
                  Text(
                    'Start Test',
                    style: TextStyle(color: Colors.white, fontSize: r.sp(15), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text, Responsive r) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: r.dp(18)),
        SizedBox(width: r.w(10)),
        Expanded(child: Text(text, style: TextStyle(fontSize: r.sp(13), color: Colors.grey[700]))),
      ],
    );
  }

  Widget _buildHandChip(String text, Color color, IconData icon, bool isFirst, Responsive r) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(10)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.dp(12)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: r.dp(18)),
          SizedBox(width: r.w(6)),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTappingPhase(Responsive r) {
    final isLeft = _currentPhase == TappingPhase.leftHand;
    final color = isLeft ? blueAccent : purpleAccent;
    final handText = isLeft ? 'LEFT HAND' : 'RIGHT HAND';

    return Column(
      children: [
        // Hand indicator
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(10)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.dp(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isLeft ? Icons.back_hand_rounded : Icons.front_hand_rounded, color: color, size: r.dp(20)),
              SizedBox(width: r.w(8)),
              Text(
                handText,
                style: TextStyle(color: color, fontSize: r.sp(16), fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Timer
        Text(
          '$_timeRemaining',
          style: TextStyle(
            fontSize: r.sp(48),
            fontWeight: FontWeight.w300,
            color: _timeRemaining <= 3 ? redAccent : Colors.black54,
          ),
        ),
        SizedBox(height: r.h(10)),
        // Tap count
        Text(
          '$_tapCount taps',
          style: TextStyle(fontSize: r.sp(20), fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        // Tap button
        GestureDetector(
          onTap: _handleTap,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: r.dp(160) + (_pulseController.value * r.dp(10)),
                height: r.dp(160) + (_pulseController.value * r.dp(10)),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: r.dp(120),
                    height: r.dp(120),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'TAP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.sp(24),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Spacer(),
        Text(
          'Tap as fast as you can!',
          style: TextStyle(fontSize: r.sp(14), color: Colors.grey[500]),
        ),
        SizedBox(height: r.h(20)),
      ],
    );
  }

  Widget _buildCompletedPhase(Responsive r) {
    final leftTaps = _leftHandResults['tap_count'] ?? 0;
    final rightTaps = _rightHandResults['tap_count'] ?? 0;
    final leftSpeed = (_leftHandResults['taps_per_second'] ?? 0).toStringAsFixed(1);
    final rightSpeed = (_rightHandResults['taps_per_second'] ?? 0).toStringAsFixed(1);
    final asymmetry = _calculateAsymmetry().toStringAsFixed(1);

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: r.h(10)),
          Container(
            width: r.dp(80),
            height: r.dp(80),
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: greenAccent, size: r.dp(45)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Test Completed!',
            style: TextStyle(fontSize: r.sp(22), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(20)),
          // Results comparison
          Row(
            children: [
              Expanded(child: _buildHandResultCard('Left Hand', leftTaps, leftSpeed, blueAccent, r)),
              SizedBox(width: r.w(12)),
              Expanded(child: _buildHandResultCard('Right Hand', rightTaps, rightSpeed, purpleAccent, r)),
            ],
          ),
          SizedBox(height: r.h(16)),
          // Asymmetry
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(r.dp(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Asymmetry Index', style: TextStyle(fontSize: r.sp(14))),
                Text('$asymmetry%', style: TextStyle(fontSize: r.sp(16), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: r.dp(20)),
                  SizedBox(width: r.w(8)),
                  Text('Continue', style: TextStyle(color: Colors.white, fontSize: r.sp(15), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandResultCard(String title, int taps, String speed, Color color, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.dp(14)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.dp(14)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: r.sp(12), color: color, fontWeight: FontWeight.w600)),
          SizedBox(height: r.h(8)),
          Text('$taps', style: TextStyle(fontSize: r.sp(28), fontWeight: FontWeight.w800, color: color)),
          Text('taps', style: TextStyle(fontSize: r.sp(12), color: Colors.grey[600])),
          SizedBox(height: r.h(4)),
          Text('$speed/sec', style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.grey[700])),
        ],
      ),
    );
  }
}
