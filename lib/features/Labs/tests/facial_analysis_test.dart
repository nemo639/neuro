import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Test phases
enum FacialPhase { instructions, resting, blinking, smiling, expressions, completed }

class FacialAnalysisTestScreen extends StatefulWidget {
  const FacialAnalysisTestScreen({super.key});

  @override
  State<FacialAnalysisTestScreen> createState() => _FacialAnalysisTestScreenState();
}

class _FacialAnalysisTestScreenState extends State<FacialAnalysisTestScreen>
    with TickerProviderStateMixin {
  
  FacialPhase _currentPhase = FacialPhase.instructions;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _recordingController;

  // Test configuration
  final int _restingDuration = 30; // Resting face recording
  final int _blinkingDuration = 20; // Natural blinking observation
  final int _smilingDuration = 10; // Smile task
  final int _expressionsDuration = 20; // Expression series
  
  int _timeRemaining = 0;
  Timer? _testTimer;
  Timer? _dataTimer;

  // Recording state
  bool _isRecording = false;
  int _framesCaptured = 0;
  
  // Simulated detection data
  int _blinkCount = 0;
  double _smileVelocity = 0;
  double _expressionRange = 0;

  // Expression tasks
  final List<Map<String, dynamic>> _expressionTasks = [
    {'name': 'Raise Eyebrows', 'icon': Icons.arrow_upward_rounded, 'duration': 4},
    {'name': 'Frown', 'icon': Icons.sentiment_very_dissatisfied_rounded, 'duration': 4},
    {'name': 'Close Eyes Tight', 'icon': Icons.visibility_off_rounded, 'duration': 4},
    {'name': 'Puff Cheeks', 'icon': Icons.face_rounded, 'duration': 4},
    {'name': 'Show Teeth', 'icon': Icons.tag_faces_rounded, 'duration': 4},
  ];
  int _currentExpressionIndex = 0;

  // Results
  Map<String, dynamic> _restingResults = {};
  Map<String, dynamic> _blinkingResults = {};
  Map<String, dynamic> _smilingResults = {};
  Map<String, dynamic> _expressionResults = {};

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color cyanAccent = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _recordingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

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
    _recordingController.dispose();
    _testTimer?.cancel();
    _dataTimer?.cancel();
    super.dispose();
  }

  void _startResting() {
    setState(() {
      _currentPhase = FacialPhase.resting;
      _timeRemaining = _restingDuration;
      _isRecording = true;
      _framesCaptured = 0;
    });
    _startRecording(_restingDuration, () {
      _restingResults = {
        'duration_ms': _restingDuration * 1000,
        'frames_captured': _framesCaptured,
        'facial_symmetry': 85 + math.Random().nextDouble() * 10,
        'muscle_tone': 70 + math.Random().nextDouble() * 20,
      };
      _startBlinking();
    });
  }

  void _startBlinking() {
    setState(() {
      _currentPhase = FacialPhase.blinking;
      _timeRemaining = _blinkingDuration;
      _blinkCount = 0;
    });
    _startRecording(_blinkingDuration, () {
      _blinkingResults = {
        'duration_ms': _blinkingDuration * 1000,
        'blink_count': _blinkCount,
        'blink_rate_per_min': _blinkCount * (60 / _blinkingDuration),
        'avg_blink_duration_ms': 150 + math.Random().nextDouble() * 100,
      };
      _startSmiling();
    });
  }

  void _startSmiling() {
    setState(() {
      _currentPhase = FacialPhase.smiling;
      _timeRemaining = _smilingDuration;
      _smileVelocity = 0;
    });
    _startRecording(_smilingDuration, () {
      _smilingResults = {
        'duration_ms': _smilingDuration * 1000,
        'smile_velocity': _smileVelocity,
        'smile_symmetry': 80 + math.Random().nextDouble() * 15,
        'max_smile_amplitude': 0.7 + math.Random().nextDouble() * 0.25,
      };
      _startExpressions();
    });
  }

  void _startExpressions() {
    setState(() {
      _currentPhase = FacialPhase.expressions;
      _currentExpressionIndex = 0;
      _timeRemaining = _expressionsDuration;
      _expressionRange = 0;
    });
    _startRecording(_expressionsDuration, () {
      _expressionResults = {
        'duration_ms': _expressionsDuration * 1000,
        'expressions_completed': _expressionTasks.length,
        'expression_range': _expressionRange,
        'hypomimia_score': math.max(0, 100 - _expressionRange * 1.2),
      };
      _finishTest();
    });
  }

  void _startRecording(int duration, VoidCallback onComplete) {
    _dataTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _framesCaptured++;
        
        // Simulate detections based on phase
        if (_currentPhase == FacialPhase.blinking && math.Random().nextDouble() > 0.92) {
          _blinkCount++;
          HapticFeedback.selectionClick();
        }
        
        if (_currentPhase == FacialPhase.smiling) {
          _smileVelocity = 0.5 + math.Random().nextDouble() * 0.5;
        }
        
        if (_currentPhase == FacialPhase.expressions) {
          _expressionRange = 60 + math.Random().nextDouble() * 35;
          // Update expression index
          final elapsed = _expressionsDuration - _timeRemaining;
          _currentExpressionIndex = (elapsed ~/ 4).clamp(0, _expressionTasks.length - 1);
        }
      });
    });

    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _dataTimer?.cancel();
        onComplete();
      }
    });
  }

  void _finishTest() {
    setState(() {
      _currentPhase = FacialPhase.completed;
      _isRecording = false;
    });
  }

  Map<String, dynamic> _getTestData() {
    // Calculate overall scores
    final blinkRate = _blinkingResults['blink_rate_per_min'] ?? 15;
    final smileVel = _smilingResults['smile_velocity'] ?? 0.5;
    final hypomimia = _expressionResults['hypomimia_score'] ?? 50;

    // Normal blink rate is 15-20 per minute, PD often shows reduced rate
    final blinkScore = blinkRate >= 12 && blinkRate <= 25 ? 100 : math.max(0, 100 - (blinkRate - 17).abs() * 5);
    
    return {
      'test_type': 'facial_analysis',
      'resting': _restingResults,
      'blinking': _blinkingResults,
      'smiling': _smilingResults,
      'expressions': _expressionResults,
      'overall_scores': {
        'blink_score': blinkScore,
        'smile_score': smileVel * 100,
        'expression_score': 100 - hypomimia,
        'combined_score': (blinkScore + smileVel * 100 + (100 - hypomimia)) / 3,
      },
      'completed': true,
    };
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _testTimer?.cancel();
    _dataTimer?.cancel();
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
            if (_isRecording) _buildRecordingBar(),
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
                const Text('Facial Analysis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(_getPhaseText(), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
      case FacialPhase.instructions:
        color = pinkAccent;
        text = 'Ready';
        icon = Icons.face_rounded;
        break;
      case FacialPhase.resting:
        color = cyanAccent;
        text = 'Resting';
        icon = Icons.sentiment_neutral_rounded;
        break;
      case FacialPhase.blinking:
        color = blueAccent;
        text = 'Blinking';
        icon = Icons.remove_red_eye_rounded;
        break;
      case FacialPhase.smiling:
        color = orangeAccent;
        text = 'Smiling';
        icon = Icons.sentiment_very_satisfied_rounded;
        break;
      case FacialPhase.expressions:
        color = pinkAccent;
        text = 'Expressions';
        icon = Icons.theater_comedy_rounded;
        break;
      case FacialPhase.completed:
        color = greenAccent;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case FacialPhase.instructions:
        return 'Position your face in the camera';
      case FacialPhase.resting:
        return 'Keep a neutral expression';
      case FacialPhase.blinking:
        return 'Blink naturally';
      case FacialPhase.smiling:
        return 'Smile when prompted';
      case FacialPhase.expressions:
        return 'Follow the expression prompts';
      case FacialPhase.completed:
        return 'Analysis complete';
    }
  }

  Widget _buildProgressBar() {
    double progress = 0;
    final totalDuration = _restingDuration + _blinkingDuration + _smilingDuration + _expressionsDuration;
    
    switch (_currentPhase) {
      case FacialPhase.instructions:
        progress = 0;
        break;
      case FacialPhase.resting:
        progress = (1 - _timeRemaining / _restingDuration) * (_restingDuration / totalDuration);
        break;
      case FacialPhase.blinking:
        progress = (_restingDuration / totalDuration) + 
                   (1 - _timeRemaining / _blinkingDuration) * (_blinkingDuration / totalDuration);
        break;
      case FacialPhase.smiling:
        progress = ((_restingDuration + _blinkingDuration) / totalDuration) + 
                   (1 - _timeRemaining / _smilingDuration) * (_smilingDuration / totalDuration);
        break;
      case FacialPhase.expressions:
        progress = ((_restingDuration + _blinkingDuration + _smilingDuration) / totalDuration) + 
                   (1 - _timeRemaining / _expressionsDuration) * (_expressionsDuration / totalDuration);
        break;
      case FacialPhase.completed:
        progress = 1.0;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 6,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [pinkAccent, orangeAccent]),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case FacialPhase.instructions:
        return _buildInstructionsPhase();
      case FacialPhase.resting:
        return _buildRestingPhase();
      case FacialPhase.blinking:
        return _buildBlinkingPhase();
      case FacialPhase.smiling:
        return _buildSmilingPhase();
      case FacialPhase.expressions:
        return _buildExpressionsPhase();
      case FacialPhase.completed:
        return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: pinkAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.face_retouching_natural_rounded, color: pinkAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Facial Analysis', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Analyze facial movements and expressions', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          // Test phases preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: softLavender.withOpacity(0.3), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _buildPhasePreview(Icons.sentiment_neutral_rounded, 'Resting Face', '30 sec', cyanAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.remove_red_eye_rounded, 'Natural Blinking', '20 sec', blueAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.sentiment_very_satisfied_rounded, 'Smile Task', '10 sec', orangeAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.theater_comedy_rounded, 'Expression Series', '20 sec', pinkAccent),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: blueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ensure good lighting and face the camera directly',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startResting,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: pinkAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: pinkAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('Start Recording', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhasePreview(IconData icon, String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Text(duration, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildCameraPreview(Widget overlay) {
    return Stack(
      children: [
        // Simulated camera preview (would be actual camera in production)
        Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face_rounded, size: 100, color: Colors.grey[700]),
                const SizedBox(height: 10),
                Text('Camera Preview', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                Text('(Simulated)', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
              ],
            ),
          ),
        ),
        // Face guide overlay
        Center(
          child: Container(
            width: 200,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        // Phase-specific overlay
        overlay,
      ],
    );
  }

  Widget _buildRestingPhase() {
    return _buildCameraPreview(
      Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.sentiment_neutral_rounded, color: cyanAccent, size: 32),
              const SizedBox(height: 8),
              const Text('Keep a neutral expression', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlinkingPhase() {
    return _buildCameraPreview(
      Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.remove_red_eye_rounded, color: blueAccent, size: 28),
                  const SizedBox(width: 12),
                  Text('$_blinkCount', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                  const Text(' blinks', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Blink naturally', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmilingPhase() {
    return _buildCameraPreview(
      Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Icon(
                    Icons.sentiment_very_satisfied_rounded,
                    color: orangeAccent,
                    size: 40 + (_pulseController.value * 10),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text('SMILE!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpressionsPhase() {
    final currentTask = _expressionTasks[_currentExpressionIndex];
    
    return _buildCameraPreview(
      Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(currentTask['icon'] as IconData, color: pinkAccent, size: 40),
              const SizedBox(height: 8),
              Text(
                currentTask['name'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              // Expression progress
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_expressionTasks.length, (index) {
                  final isCompleted = index < _currentExpressionIndex;
                  final isCurrent = index == _currentExpressionIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isCurrent ? 24 : 12,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCompleted ? greenAccent : (isCurrent ? pinkAccent : Colors.grey[600]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedPhase() {
    final data = _getTestData();
    final scores = data['overall_scores'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: greenAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: greenAccent, size: 45),
          ),
          const SizedBox(height: 20),
          const Text('Analysis Complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          // Score cards
          Row(
            children: [
              Expanded(child: _buildScoreCard('Blink', scores['blink_score'], blueAccent, Icons.remove_red_eye_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildScoreCard('Smile', scores['smile_score'], orangeAccent, Icons.sentiment_satisfied_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildScoreCard('Expression', scores['expression_score'], pinkAccent, Icons.theater_comedy_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          // Combined score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Overall Facial Score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  '${(scores['combined_score'] as double).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: greenAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Detailed results
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _buildDetailRow('Blink Rate', '${(_blinkingResults['blink_rate_per_min'] ?? 0).toStringAsFixed(1)}/min'),
                const Divider(height: 16),
                _buildDetailRow('Smile Symmetry', '${(_smilingResults['smile_symmetry'] ?? 0).toStringAsFixed(0)}%'),
                const Divider(height: 16),
                _buildDetailRow('Expression Range', '${(_expressionResults['expression_range'] ?? 0).toStringAsFixed(0)}%'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(color: greenAccent, borderRadius: BorderRadius.circular(16)),
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

  Widget _buildScoreCard(String title, double score, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text('${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: darkCard, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _recordingController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: redAccent.withOpacity(0.5 + _recordingController.value * 0.5),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Text('REC', style: TextStyle(color: redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('FRAMES', '$_framesCaptured', blueAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('TIME', '${_timeRemaining}s', orangeAccent),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}