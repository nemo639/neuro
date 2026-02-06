import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StoryRecallTestScreen extends StatefulWidget {
  const StoryRecallTestScreen({super.key});

  @override
  State<StoryRecallTestScreen> createState() => _StoryRecallTestScreenState();
}
enum TestPhase { instructions, listening, recording, completed }
class _StoryRecallTestScreenState extends State<StoryRecallTestScreen>
    with TickerProviderStateMixin {
  
  // Test phases
  
  TestPhase _currentPhase = TestPhase.instructions;

  // Animation controllers
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Test state
  int _currentTrial = 0;
  final int _totalTrials = 1; // Story recall is typically 1 story
  bool _isPlaying = false;
  bool _isRecording = false;
  double _playbackProgress = 0.0;
  double _recordingProgress = 0.0;
  Timer? _progressTimer;
  Timer? _recordingTimer;

  // Timing
  final int _storyDurationSeconds = 45; // Story audio length
  final int _maxRecordingSeconds = 120; // Max recording time
  int _recordingSeconds = 0;
  DateTime? _listeningStartTime;
  DateTime? _recordingStartTime;

  // Collected data
  final Map<String, dynamic> _testData = {
    'story_id': 'story_01',
    'story_duration_ms': 0,
    'recording_duration_ms': 0,
    'listening_start': null,
    'recording_start': null,
    'audio_path': null,
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

  // Sample story text (for display during listening)
  final String _storyText = '''
Sarah woke up early on Saturday morning. She had planned to visit her grandmother who lived in a small village near the mountains. She packed a basket with fresh fruits, homemade cookies, and a warm sweater as a gift.

The bus journey took about two hours. When Sarah arrived, her grandmother was waiting at the door with a big smile. They spent the afternoon in the garden, talking about old memories and watching the birds.

Before leaving, Sarah promised to visit again next month. Her grandmother gave her a jar of honey from the local bees. On the way home, Sarah felt happy and grateful for the wonderful day.
''';

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
      duration: const Duration(milliseconds: 2000),
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
    _pageController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _progressTimer?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _currentPhase = TestPhase.listening;
      _isPlaying = true;
      _playbackProgress = 0.0;
      _listeningStartTime = DateTime.now();
    });

    // Simulate audio playback progress
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _playbackProgress += 0.1 / _storyDurationSeconds;
        if (_playbackProgress >= 1.0) {
          _playbackProgress = 1.0;
          _isPlaying = false;
          timer.cancel();
          _testData['story_duration_ms'] = 
              DateTime.now().difference(_listeningStartTime!).inMilliseconds;
          
          // Auto-transition to recording after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _startRecording();
          });
        }
      });
    });
  }

  void _startRecording() {
    setState(() {
      _currentPhase = TestPhase.recording;
      _isRecording = true;
      _recordingProgress = 0.0;
      _recordingSeconds = 0;
      _recordingStartTime = DateTime.now();
    });

    // Recording timer
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
        _recordingProgress = _recordingSeconds / _maxRecordingSeconds;
        
        if (_recordingSeconds >= _maxRecordingSeconds) {
          _stopRecording();
        }
      });
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    
    setState(() {
      _isRecording = false;
      _testData['recording_duration_ms'] = 
          DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      _testData['audio_path'] = 'recordings/story_recall_${DateTime.now().millisecondsSinceEpoch}.wav';
      _testData['completed'] = true;
      _currentPhase = TestPhase.completed;
    });
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    
    // Return collected data to previous screen
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit test
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
            _buildMobileHeader(),
            _buildProgressBar(),
            Expanded(
              child: _buildTestArea(),
            ),
            if (_currentPhase != TestPhase.instructions && 
                _currentPhase != TestPhase.completed)
              _buildMobileMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back button
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Story Recall',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getPhaseText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _currentPhase == TestPhase.completed 
                  ? greenAccent.withOpacity(0.1)
                  : blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentPhase == TestPhase.completed 
                      ? Icons.check_circle_rounded 
                      : Icons.access_time_rounded,
                  color: _currentPhase == TestPhase.completed 
                      ? greenAccent 
                      : blueAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentPhase == TestPhase.completed ? 'Done' : '5 min',
                  style: TextStyle(
                    color: _currentPhase == TestPhase.completed 
                        ? greenAccent 
                        : blueAccent,
                    fontSize: 12,
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

  Widget _buildProgressBar() {
    double progress = 0.0;
    switch (_currentPhase) {
      case TestPhase.instructions:
        progress = 0.0;
        break;
      case TestPhase.listening:
        progress = 0.25 + (_playbackProgress * 0.25);
        break;
      case TestPhase.recording:
        progress = 0.5 + (_recordingProgress * 0.4);
        break;
      case TestPhase.completed:
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
            gradient: LinearGradient(
              colors: [blueAccent, greenAccent],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileMetrics() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniMetric(
            _isPlaying ? 'PLAYING' : (_isRecording ? 'RECORDING' : 'READY'),
            _isRecording 
                ? _formatTime(_recordingSeconds)
                : '${(_playbackProgress * _storyDurationSeconds).toInt()}s',
            _isRecording ? redAccent : blueAccent,
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.1),
          ),
          _buildMiniMetric(
            'PHASE',
            '${_currentPhase.index + 1}/4',
            greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          // Test icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.record_voice_over_rounded,
              color: blueAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Title and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Story Recall',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPhaseText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _currentPhase == TestPhase.completed 
                      ? Icons.check_circle_rounded 
                      : Icons.access_time_rounded,
                  color: _currentPhase == TestPhase.completed 
                      ? greenAccent 
                      : Colors.white.withOpacity(0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _currentPhase == TestPhase.completed 
                      ? 'Completed' 
                      : 'Trial ${_currentTrial + 1}/$_totalTrials',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Exit button
          GestureDetector(
            onTap: _exitTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case TestPhase.instructions:
        return 'Read the instructions carefully';
      case TestPhase.listening:
        return 'Listen to the story attentively';
      case TestPhase.recording:
        return 'Repeat the story in your own words';
      case TestPhase.completed:
        return 'Test completed successfully';
    }
  }

  Widget _buildTestArea() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
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
      case TestPhase.instructions:
        return _buildInstructionsPhase();
      case TestPhase.listening:
        return _buildListeningPhase();
      case TestPhase.recording:
        return _buildRecordingPhase();
      case TestPhase.completed:
        return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.headphones_rounded,
              color: blueAccent,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          // Title
          const Text(
            'Story Recall Test',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildInstructionItem(1, 'Listen carefully to the short story'),
                const SizedBox(height: 10),
                _buildInstructionItem(2, 'Try to remember as many details as possible'),
                const SizedBox(height: 10),
                _buildInstructionItem(3, 'After the story ends, repeat it in your own words'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Duration info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_rounded, color: Colors.grey[600], size: 18),
              const SizedBox(width: 6),
              Text(
                'Estimated time: 5 minutes',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Start button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _startListening();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: blueAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: blueAccent.withOpacity(0.4),
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
                    'Start Listening',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(int number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: blueAccent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListeningPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Animated speaker icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 90 + (_pulseController.value * 15),
                height: 90 + (_pulseController.value * 15),
                decoration: BoxDecoration(
                  color: blueAccent.withOpacity(0.1 + _pulseController.value * 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: blueAccent,
                  size: 45,
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Status text
          const Text(
            'Playing Story...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Listen carefully and try to remember the details',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Progress bar
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _playbackProgress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blueAccent, purpleAccent],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Time
          Text(
            '${(_playbackProgress * _storyDurationSeconds).toInt()}s / ${_storyDurationSeconds}s',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          // Tip card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates_rounded,
                  color: purpleAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Focus on key details: names, places, numbers, and sequence of events',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildRecordingPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 100 + (_pulseController.value * 20),
                height: 100 + (_pulseController.value * 20),
                decoration: BoxDecoration(
                  color: redAccent.withOpacity(0.1 + _pulseController.value * 0.15),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: redAccent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Recording text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Recording...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Repeat the story in your own words',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          // Recording time
          Text(
            _formatTime(_recordingSeconds),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w300,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 20),
          // Audio waveform visualization
          Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 60),
                  painter: WaveformPainter(
                    animation: _waveController.value,
                    color: redAccent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Stop button
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              _stopRecording();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: darkCard.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Stop Recording',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget _buildCompletedPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Success icon
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: greenAccent,
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Test Completed!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recording has been saved successfully',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Story Duration', '${(_testData['story_duration_ms'] / 1000).toStringAsFixed(1)}s'),
                const SizedBox(height: 10),
                _buildSummaryRow('Recording Duration', '${(_testData['recording_duration_ms'] / 1000).toStringAsFixed(1)}s'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Continue button
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: greenAccent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Real-time Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Objective performance metrics',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          // Metrics grid
          Expanded(
            child: Column(
              children: [
                // Row 1
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'LISTENING TIME',
                        '${(_playbackProgress * _storyDurationSeconds).toInt()}s',
                        mintGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'RECORDING TIME',
                        '${_recordingSeconds}s',
                        softLavender,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row 2
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'PHASE',
                        _currentPhase.name.toUpperCase(),
                        creamBeige,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'STATUS',
                        _isRecording ? 'REC' : (_isPlaying ? 'PLAY' : 'READY'),
                        _isRecording ? const Color(0xFFFFCDD2) : mintGreen,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Phase progress
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEST PROGRESS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildProgressStep('Instructions', _currentPhase.index >= 0),
                      _buildProgressStep('Listening', _currentPhase.index >= 1),
                      _buildProgressStep('Recording', _currentPhase.index >= 2),
                      _buildProgressStep('Completed', _currentPhase.index >= 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: completed ? greenAccent : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: completed ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: 13,
              fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

// Waveform painter for recording visualization
class WaveformPainter extends CustomPainter {
  final double animation;
  final Color color;

  WaveformPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barCount = 40;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      final normalizedPosition = i / barCount;
      
      // Create wave effect
      final waveOffset = math.sin((normalizedPosition + animation) * math.pi * 4);
      final randomHeight = (0.3 + 0.7 * ((math.sin(i * 0.5 + animation * 10) + 1) / 2));
      final height = size.height * 0.4 * randomHeight * (0.5 + waveOffset * 0.5);
      
      canvas.drawLine(
        Offset(x, size.height / 2 - height),
        Offset(x, size.height / 2 + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}