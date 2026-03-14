import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:neuroverse/core/audio_recorder_service.dart';

class StoryRecallTestScreen extends StatefulWidget {
  const StoryRecallTestScreen({super.key});

  @override
  State<StoryRecallTestScreen> createState() => _StoryRecallTestScreenState();
}

enum TestPhase { instructions, listening, recording, completed }

class _StoryRecallTestScreenState extends State<StoryRecallTestScreen>
    with TickerProviderStateMixin {
  TestPhase _currentPhase = TestPhase.instructions;

  // Animation controllers
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // TTS
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  // Audio recorder
  final AudioRecorderService _audioRecorder = AudioRecorderService();

  // Test state
  int _currentTrial = 0;
  final int _totalTrials = 1;
  bool _isPlaying = false;
  bool _isRecording = false;
  double _playbackProgress = 0.0;
  double _recordingProgress = 0.0;
  Timer? _progressTimer;
  Timer? _recordingTimer;

  // Timing
  int _storyDurationSeconds = 45;
  final int _maxRecordingSeconds = 120;
  int _recordingSeconds = 0;
  int _playbackSeconds = 0;
  DateTime? _listeningStartTime;
  DateTime? _recordingStartTime;

  // Currently selected story
  late Map<String, String> _selectedStory;

  // Collected data
  late Map<String, dynamic> _testData;

  // ── Clinical stories (DementiaBank / EWA-DB complexity level) ──
  // Each story has ~60-80 words, 8-12 semantic units for scoring
  static final List<Map<String, String>> _stories = [
    {
      'id': 'story_grandmother',
      'title': 'The Visit',
      'text':
          'Sarah woke up early on Saturday morning. She had planned to visit her grandmother '
          'who lived in a small village near the mountains. She packed a basket with fresh fruits, '
          'homemade cookies, and a warm sweater as a gift. The bus journey took about two hours. '
          'When Sarah arrived, her grandmother was waiting at the door with a big smile. They spent '
          'the afternoon in the garden, talking about old memories and watching the birds. Before leaving, '
          'Sarah promised to visit again next month. Her grandmother gave her a jar of honey from the local bees.',
    },
    {
      'id': 'story_fire',
      'title': 'The Fire',
      'text':
          'A woman was washing dishes in her kitchen when she noticed smoke coming from the living room. '
          'She ran in and found that a candle had fallen on the carpet. The flames were spreading quickly. '
          'She grabbed a blanket and tried to smother the fire, but it was too large. She called the fire '
          'department and took her two children outside to safety. The firemen arrived in eight minutes and '
          'put out the fire. The living room was badly damaged, but no one was hurt. The family stayed with '
          'neighbours that night. The insurance company paid for the repairs the following week.',
    },
    {
      'id': 'story_market',
      'title': 'The Market',
      'text':
          'Every Sunday, Mr. Ahmed goes to the local market to buy vegetables and fruits for the week. '
          'Last Sunday he arrived at seven in the morning while it was still cool. He bought tomatoes, '
          'onions, and a large watermelon from his favourite stall. While walking through the market he '
          'met his old friend Khalid, who was selling handmade baskets. They sat together and drank tea. '
          'On his way home, Mr. Ahmed noticed a young boy who had lost his mother. He helped the boy find '
          'her near the fish stall. The mother thanked him and offered him a bag of fresh dates.',
    },
    {
      'id': 'story_hospital',
      'title': 'The Hospital',
      'text':
          'Last Tuesday, a young man named Ali was riding his bicycle to work when a car turned without '
          'signalling. Ali swerved to avoid it and fell on the road. A shopkeeper nearby called an ambulance '
          'which arrived in ten minutes. At the hospital the doctor found that Ali had broken his left arm '
          'and had several cuts on his knees. They put a plaster cast on his arm and cleaned the wounds. '
          'Ali\'s boss came to visit him that evening and told him to rest for two weeks. His colleagues '
          'collected money to help with the medical bills. Ali went home the next morning.',
    },
    {
      'id': 'story_school',
      'title': 'The School Trip',
      'text':
          'The children from the primary school went on a trip to the science museum last Wednesday. '
          'They travelled by bus and their teacher Mrs. Fatima sat at the front. At the museum they saw '
          'dinosaur bones, a model of the solar system, and a live chemistry show. During lunch one boy '
          'named Hassan accidentally spilled his juice on the exhibit sign. The museum guard was upset but '
          'Mrs. Fatima apologised and cleaned it up. After lunch they watched a film about volcanoes in the '
          'theatre. On the way home the children sang songs on the bus. They arrived back at school at four '
          'o\'clock and their parents were waiting outside.',
    },
  ];

  // Design colors
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

    // Pick a random story
    _selectedStory = _stories[math.Random().nextInt(_stories.length)];

    _testData = {
      'story_id': _selectedStory['id'],
      'story_title': _selectedStory['title'],
      'story_duration_ms': 0,
      'recording_duration_ms': 0,
      'listening_start': null,
      'recording_start': null,
      'audio_path': null,
      'completed': false,
    };

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

    _initTts();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45); // Slow, clear speech for clinical test
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(() {
      // TTS finished reading the story
      if (mounted && _currentPhase == TestPhase.listening) {
        _progressTimer?.cancel();
        setState(() {
          _isPlaying = false;
          _playbackProgress = 1.0;
          _testData['story_duration_ms'] =
              DateTime.now().difference(_listeningStartTime!).inMilliseconds;
        });
        // Auto-transition to recording after a short pause
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startRecording();
        });
      }
    });

    setState(() => _ttsReady = true);
  }

  @override
  void dispose() {
    _tts.stop();
    _audioRecorder.dispose();
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
      _playbackSeconds = 0;
      _listeningStartTime = DateTime.now();
    });

    // Start TTS
    _tts.speak(_selectedStory['text']!);

    // Progress timer (visual only — actual end is driven by TTS completion)
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _playbackSeconds++;
        // Estimate progress based on ~45s average read time
        _playbackProgress =
            (_playbackSeconds / _storyDurationSeconds).clamp(0.0, 0.95);
      });
    });
  }

  Future<void> _startRecording() async {
    final fileName = 'story_recall_${DateTime.now().millisecondsSinceEpoch}';
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
      _currentPhase = TestPhase.recording;
      _isRecording = true;
      _recordingProgress = 0.0;
      _recordingSeconds = 0;
      _recordingStartTime = DateTime.now();
    });

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

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final audioPath = await _audioRecorder.stopRecording();

    setState(() {
      _isRecording = false;
      _testData['recording_duration_ms'] =
          DateTime.now().difference(_recordingStartTime!).inMilliseconds;
      _testData['audio_path'] = audioPath ?? '';
      _testData['completed'] = true;
      _currentPhase = TestPhase.completed;
    });
  }

  Future<void> _retakeRecording() async {
    HapticFeedback.mediumImpact();
    await _audioRecorder.cancelRecording();
    setState(() {
      _testData['completed'] = false;
      _testData.remove('recording_duration_ms');
      _testData.remove('audio_path');
      _recordingSeconds = 0;
      _recordingProgress = 0.0;
    });
    _startRecording();
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _testData);
  }

  void _exitTest() {
    _tts.stop();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Test?'),
        content: const Text(
            'Your progress will be lost. Are you sure you want to exit?'),
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
            gradient: const LinearGradient(
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
            _isPlaying
                ? 'SPEAKING'
                : (_isRecording ? 'RECORDING' : 'READY'),
            _isRecording
                ? _formatTime(_recordingSeconds)
                : '${_playbackSeconds}s',
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
          const Text(
            'Story Recall Test',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Story title badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: purpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '"${_selectedStory['title']}"',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: purpleAccent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildInstructionItem(
                    1, 'The phone will read a short story aloud'),
                const SizedBox(height: 10),
                _buildInstructionItem(
                    2, 'Listen carefully — remember as many details as possible'),
                const SizedBox(height: 10),
                _buildInstructionItem(
                    3, 'After the story ends, repeat it in your own words'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.volume_up_rounded, color: Colors.grey[600], size: 18),
              const SizedBox(width: 6),
              Text(
                'Make sure your volume is turned up',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _ttsReady
                ? () {
                    HapticFeedback.mediumImpact();
                    _startListening();
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: _ttsReady ? blueAccent : Colors.grey,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: blueAccent.withOpacity(_ttsReady ? 0.4 : 0),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _ttsReady ? 'Start Listening' : 'Preparing...',
                    style: const TextStyle(
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
          decoration: const BoxDecoration(
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
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 90 + (_pulseController.value * 15),
                height: 90 + (_pulseController.value * 15),
                decoration: BoxDecoration(
                  color: blueAccent
                      .withOpacity(0.1 + _pulseController.value * 0.1),
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
          const Text(
            'Reading Story Aloud...',
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
          Text(
            '${_playbackSeconds}s',
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
                const Icon(
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
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 100 + (_pulseController.value * 20),
                height: 100 + (_pulseController.value * 20),
                decoration: BoxDecoration(
                  color: redAccent
                      .withOpacity(0.1 + _pulseController.value * 0.15),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
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
          // Waveform
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Story',
                    '"${_selectedStory['title']}"'),
                const SizedBox(height: 10),
                _buildSummaryRow('Story Duration',
                    '${(_testData['story_duration_ms'] / 1000).toStringAsFixed(1)}s'),
                const SizedBox(height: 10),
                _buildSummaryRow('Recording Duration',
                    '${(_testData['recording_duration_ms'] / 1000).toStringAsFixed(1)}s'),
              ],
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
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
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
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _retakeRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Retake Recording',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

      final waveOffset =
          math.sin((normalizedPosition + animation) * math.pi * 4);
      final randomHeight =
          (0.3 + 0.7 * ((math.sin(i * 0.5 + animation * 10) + 1) / 2));
      final height =
          size.height * 0.4 * randomHeight * (0.5 + waveOffset * 0.5);

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
