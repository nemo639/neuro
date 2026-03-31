import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/audio_recorder_service.dart';
import '../../../core/responsive.dart';

// Test phases - must be outside class
enum SustainedVowelPhase { instructions, recording, completed }

class SustainedVowelTestScreen extends StatefulWidget {
  const SustainedVowelTestScreen({super.key});

  @override
  State<SustainedVowelTestScreen> createState() => _SustainedVowelTestScreenState();
}

class _SustainedVowelTestScreenState extends State<SustainedVowelTestScreen>
    with TickerProviderStateMixin {

  SustainedVowelPhase _currentPhase = SustainedVowelPhase.instructions;

  // Animation controllers
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _breatheController;

  // Test state
  int _currentTrial = 0;
  final int _totalTrials = 3; // 3 vowel recordings: "Ahhh", "Eeee", "Oooo"
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  Timer? _recordingTimer;

  // Vowels to test
  final List<Map<String, dynamic>> _vowels = [
    {'sound': 'Ahhh', 'symbol': 'A', 'color': Color(0xFF3B82F6)},
    {'sound': 'Eeee', 'symbol': 'E', 'color': Color(0xFF8B5CF6)},
    {'sound': 'Oooo', 'symbol': 'O', 'color': Color(0xFFF97316)},
  ];

  // Audio recorder
  final AudioRecorderService _audioRecorder = AudioRecorderService();

  // Timing
  final int _targetDurationSeconds = 5; // Hold each vowel for 5 seconds
  int _recordingSeconds = 0;
  int _recordingMilliseconds = 0;
  DateTime? _recordingStartTime;

  // Collected data
  final List<Map<String, dynamic>> _trialResults = [];
  final Map<String, dynamic> _testData = {
    'trials': [],
    'total_duration_ms': 0,
    'completed': false,
  };

  // Design colors (matching NeuroVerse palette)
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color redAccent = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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
    _audioRecorder.dispose();
    _pageController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _breatheController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _currentVowel => _vowels[_currentTrial];

  Future<void> _startRecording() async {
    final vowelSymbol = _currentVowel['symbol'].toString().toLowerCase();
    final fileName = 'vowel_${vowelSymbol}_${DateTime.now().millisecondsSinceEpoch}';
    final started = await _audioRecorder.startRecording(fileName);

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone permission required for recording'),
          backgroundColor: redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _currentPhase = SustainedVowelPhase.recording;
      _isRecording = true;
      _recordingProgress = 0.0;
      _recordingSeconds = 0;
      _recordingMilliseconds = 0;
      _recordingStartTime = DateTime.now();
    });

    // Recording timer - update every 100ms for smooth progress
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _recordingMilliseconds += 100;
        _recordingSeconds = _recordingMilliseconds ~/ 1000;
        _recordingProgress = _recordingMilliseconds / (_targetDurationSeconds * 1000);

        if (_recordingMilliseconds >= _targetDurationSeconds * 1000) {
          _stopRecording();
        }
      });
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final duration = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
    final audioPath = await _audioRecorder.stopRecording();

    // Save trial result
    _trialResults.add({
      'vowel': _currentVowel['sound'],
      'duration_ms': duration,
      'target_duration_ms': _targetDurationSeconds * 1000,
      'audio_path': audioPath ?? '',
    });

    setState(() {
      _isRecording = false;

      if (_currentTrial < _totalTrials - 1) {
        // Move to next vowel
        _currentTrial++;
        _currentPhase = SustainedVowelPhase.instructions;
      } else {
        // All trials completed
        _testData['trials'] = _trialResults;
        _testData['total_duration_ms'] = _trialResults.fold(0, (sum, t) => sum + (t['duration_ms'] as int));
        _testData['completed'] = true;
        _currentPhase = SustainedVowelPhase.completed;
      }
    });
  }

  Future<void> _retakeRecording() async {
    HapticFeedback.mediumImpact();
    await _audioRecorder.cancelRecording();
    setState(() {
      // Clear all trials and restart from the first vowel
      _trialResults.clear();
      _testData['completed'] = false;
      _testData['trials'] = [];
      _testData['total_duration_ms'] = 0;
      _currentTrial = 0;
      _recordingSeconds = 0;
      _recordingMilliseconds = 0;
      _recordingProgress = 0.0;
      _currentPhase = SustainedVowelPhase.instructions;
    });
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _testData);
  }

  void _exitTest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost. Are you sure you want to exit?'),
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
            Expanded(
              child: _buildTestArea(r),
            ),
            if (_currentPhase == SustainedVowelPhase.recording)
              _buildMetricsBar(r),
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
          // Back button
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
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: r.dp(18),
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(width: r.w(16)),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sustained Vowel',
                  style: TextStyle(
                    fontSize: r.sp(20),
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: r.h(2)),
                Text(
                  _getPhaseText(),
                  style: TextStyle(
                    fontSize: r.sp(13),
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Trial counter
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(6)),
            decoration: BoxDecoration(
              color: (_currentVowel['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentPhase == SustainedVowelPhase.completed
                      ? Icons.check_circle_rounded
                      : Icons.graphic_eq_rounded,
                  color: _currentPhase == SustainedVowelPhase.completed
                      ? greenAccent
                      : _currentVowel['color'] as Color,
                  size: r.dp(16),
                ),
                SizedBox(width: r.w(6)),
                Text(
                  _currentPhase == SustainedVowelPhase.completed
                      ? 'Done'
                      : '${_currentTrial + 1}/$_totalTrials',
                  style: TextStyle(
                    color: _currentPhase == SustainedVowelPhase.completed
                        ? greenAccent
                        : _currentVowel['color'] as Color,
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case SustainedVowelPhase.instructions:
        return 'Get ready to say "${_currentVowel['sound']}"';
      case SustainedVowelPhase.recording:
        return 'Hold the sound steady';
      case SustainedVowelPhase.completed:
        return 'All vowels recorded';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    double progress = (_currentTrial / _totalTrials);
    if (_currentPhase == SustainedVowelPhase.recording) {
      progress += (_recordingProgress / _totalTrials);
    } else if (_currentPhase == SustainedVowelPhase.completed) {
      progress = 1.0;
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
            gradient: LinearGradient(
              colors: [blueAccent, purpleAccent, orangeAccent],
            ),
            borderRadius: BorderRadius.circular(r.dp(3)),
          ),
        ),
      ),
    );
  }

  Widget _buildTestArea(Responsive r) {
    return Container(
      margin: EdgeInsets.all(r.dp(20)),
      padding: EdgeInsets.all(r.dp(24)),
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
      case SustainedVowelPhase.instructions:
        return _buildInstructionsPhase(r);
      case SustainedVowelPhase.recording:
        return _buildRecordingPhase(r);
      case SustainedVowelPhase.completed:
        return _buildCompletedPhase(r);
    }
  }

  Widget _buildInstructionsPhase(Responsive r) {
    final vowelColor = _currentVowel['color'] as Color;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(10)),
          // Vowel display with breathing animation
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              return Container(
                width: r.dp(120) + (_breatheController.value * r.dp(15)),
                height: r.dp(120) + (_breatheController.value * r.dp(15)),
                decoration: BoxDecoration(
                  color: vowelColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: vowelColor.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    _currentVowel['symbol'],
                    style: TextStyle(
                      fontSize: r.sp(56),
                      fontWeight: FontWeight.w800,
                      color: vowelColor,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: r.h(24)),
          // Sound text
          Text(
            'Say "${_currentVowel['sound']}"',
            style: TextStyle(
              fontSize: r.sp(28),
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Hold the sound for $_targetDurationSeconds seconds',
            style: TextStyle(
              fontSize: r.sp(14),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: r.h(24)),
          // Instructions card
          Container(
            padding: EdgeInsets.all(r.dp(16)),
            decoration: BoxDecoration(
              color: vowelColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(r.dp(16)),
              border: Border.all(color: vowelColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.air_rounded, 'Take a deep breath first', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.volume_up_rounded, 'Keep volume consistent', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.straighten_rounded, 'Hold pitch steady', r),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          // Trial indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalTrials, (index) {
              final isCompleted = index < _currentTrial;
              final isCurrent = index == _currentTrial;
              final trialColor = _vowels[index]['color'] as Color;

              return Container(
                margin: EdgeInsets.symmetric(horizontal: r.w(6)),
                width: isCurrent ? r.dp(36) : r.dp(28),
                height: isCurrent ? r.dp(36) : r.dp(28),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? greenAccent
                      : (isCurrent ? trialColor : Colors.grey[200]),
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: trialColor, width: 3)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: r.dp(16))
                      : Text(
                          _vowels[index]['symbol'],
                          style: TextStyle(
                            fontSize: r.sp(isCurrent ? 16 : 12),
                            fontWeight: FontWeight.w700,
                            color: isCurrent ? Colors.white : Colors.grey[500],
                          ),
                        ),
                ),
              );
            }),
          ),
          SizedBox(height: r.h(28)),
          // Start button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _startRecording();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(48), vertical: r.h(16)),
              decoration: BoxDecoration(
                color: vowelColor,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: vowelColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, color: Colors.white, size: r.dp(22)),
                  SizedBox(width: r.w(10)),
                  Text(
                    _currentTrial == 0 ? 'Start Recording' : 'Record Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.h(10)),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text, Responsive r) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: r.dp(20)),
        SizedBox(width: r.w(12)),
        Text(
          text,
          style: TextStyle(
            fontSize: r.sp(13),
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingPhase(Responsive r) {
    final vowelColor = _currentVowel['color'] as Color;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(10)),
          // Animated vowel with pulse
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: r.dp(130) + (_pulseController.value * r.dp(30)),
                height: r.dp(130) + (_pulseController.value * r.dp(30)),
                decoration: BoxDecoration(
                  color: vowelColor.withOpacity(0.1 + _pulseController.value * 0.1),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: EdgeInsets.all(r.dp(20)),
                  decoration: BoxDecoration(
                    color: vowelColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: vowelColor.withOpacity(0.4),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _currentVowel['symbol'],
                      style: TextStyle(
                        fontSize: r.sp(40),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: r.h(24)),
          // Recording indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: r.dp(12),
                height: r.dp(12),
                decoration: BoxDecoration(
                  color: redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: r.w(8)),
              Text(
                'Say "${_currentVowel['sound']}"',
                style: TextStyle(
                  fontSize: r.sp(22),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Hold steady...',
            style: TextStyle(
              fontSize: r.sp(14),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: r.h(24)),
          // Circular progress timer
          SizedBox(
            width: r.dp(120),
            height: r.dp(120),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: r.dp(120),
                  height: r.dp(120),
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: r.dp(8),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[200]!),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: r.dp(120),
                  height: r.dp(120),
                  child: CircularProgressIndicator(
                    value: _recordingProgress,
                    strokeWidth: r.dp(8),
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(vowelColor),
                  ),
                ),
                // Timer text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_recordingSeconds}s',
                      style: TextStyle(
                        fontSize: r.sp(32),
                        fontWeight: FontWeight.w700,
                        color: vowelColor,
                      ),
                    ),
                    Text(
                      'of ${_targetDurationSeconds}s',
                      style: TextStyle(
                        fontSize: r.sp(12),
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          // Waveform
          Container(
            height: r.h(50),
            margin: EdgeInsets.symmetric(horizontal: r.w(10)),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(double.infinity, r.h(50)),
                  painter: VowelWaveformPainter(
                    animation: _waveController.value,
                    color: vowelColor,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: r.h(20)),
          // Stop early button
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _stopRecording();
            },
            child: Text(
              'Stop Early',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.sp(14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedPhase(Responsive r) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(20)),
          // Success icon
          Container(
            width: r.dp(100),
            height: r.dp(100),
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: greenAccent,
              size: r.dp(60),
            ),
          ),
          SizedBox(height: r.h(24)),
          Text(
            'All Vowels Recorded!',
            style: TextStyle(
              fontSize: r.sp(24),
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Voice analysis data has been captured',
            style: TextStyle(
              fontSize: r.sp(14),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: r.h(28)),
          // Results summary
          Container(
            padding: EdgeInsets.all(r.dp(16)),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(r.dp(16)),
            ),
            child: Column(
              children: [
                ...List.generate(_trialResults.length, (index) {
                  final trial = _trialResults[index];
                  final vowelColor = _vowels[index]['color'] as Color;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < _trialResults.length - 1 ? r.h(12) : 0),
                    child: Row(
                      children: [
                        Container(
                          width: r.dp(36),
                          height: r.dp(36),
                          decoration: BoxDecoration(
                            color: vowelColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _vowels[index]['symbol'],
                              style: TextStyle(
                                fontSize: r.sp(16),
                                fontWeight: FontWeight.w700,
                                color: vowelColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: r.w(12)),
                        Expanded(
                          child: Text(
                            '"${trial['vowel']}"',
                            style: TextStyle(
                              fontSize: r.sp(14),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '${(trial['duration_ms'] / 1000).toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontSize: r.sp(14),
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: r.w(8)),
                        Icon(
                          Icons.check_circle_rounded,
                          color: greenAccent,
                          size: r.dp(20),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: r.h(28)),
          // Continue button
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(48), vertical: r.h(16)),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: greenAccent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: r.dp(22)),
                  SizedBox(width: r.w(8)),
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.h(12)),
          GestureDetector(
            onTap: _retakeRecording,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(48), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.dp(16)),
                border: Border.all(color: Colors.black.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.grey[700], size: r.dp(20)),
                  SizedBox(width: r.w(8)),
                  Text(
                    'Retake Recording',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: r.sp(15),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.h(20)),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(Responsive r) {
    final vowelColor = _currentVowel['color'] as Color;

    return Container(
      margin: EdgeInsets.all(r.dp(20)),
      padding: EdgeInsets.all(r.dp(16)),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(r.dp(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniMetric('VOWEL', _currentVowel['symbol'], vowelColor, r),
          Container(
            width: r.w(1),
            height: r.h(40),
            color: Colors.white.withOpacity(0.1),
          ),
          _buildMiniMetric('TIME', '${_recordingSeconds}s', greenAccent, r),
          Container(
            width: r.w(1),
            height: r.h(40),
            color: Colors.white.withOpacity(0.1),
          ),
          _buildMiniMetric('TRIAL', '${_currentTrial + 1}/$_totalTrials', purpleAccent, r),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color, Responsive r) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: r.sp(10),
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: r.h(4)),
        Row(
          children: [
            Container(
              width: r.dp(8),
              height: r.dp(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: r.w(6)),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: r.sp(18),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Waveform painter for vowel visualization
class VowelWaveformPainter extends CustomPainter {
  final double animation;
  final Color color;

  VowelWaveformPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barCount = 30;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;

      // Create smooth wave pattern
      final wave1 = math.sin((i / barCount + animation) * math.pi * 3);
      final wave2 = math.sin((i / barCount + animation * 1.5) * math.pi * 5) * 0.5;
      final combined = (wave1 + wave2) / 1.5;

      final height = size.height * 0.4 * (0.3 + 0.7 * ((combined + 1) / 2));

      canvas.drawLine(
        Offset(x, size.height / 2 - height),
        Offset(x, size.height / 2 + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VowelWaveformPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
