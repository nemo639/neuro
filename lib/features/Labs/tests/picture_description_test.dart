import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/audio_recorder_service.dart';
import '../../../core/responsive.dart';

// Test phases - must be outside class
enum PictureDescPhase { instructions, viewing, recording, completed }

class PictureDescriptionTestScreen extends StatefulWidget {
  const PictureDescriptionTestScreen({super.key});

  @override
  State<PictureDescriptionTestScreen> createState() => _PictureDescriptionTestScreenState();
}

class _PictureDescriptionTestScreenState extends State<PictureDescriptionTestScreen>
    with TickerProviderStateMixin {
  
  PictureDescPhase _currentPhase = PictureDescPhase.instructions;

  // Animation controllers
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Test state
  int _currentTrial = 0;
  final int _totalTrials = 3; // 3 images to describe
  bool _isRecording = false;
  Timer? _recordingTimer;
  Timer? _viewingTimer;

  // Audio recorder
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  
  // Clinical scene images for picture description (DementiaBank / BDAE protocol)
  // Place actual images in assets/images/speech/
  final List<Map<String, dynamic>> _images = [
    {
      'id': 'cookie_theft',
      'title': 'Cookie Theft',
      'description': 'A kitchen scene with a mother, children, and overflowing sink',
      'asset': 'assets/images/speech/cookie_theft.png',
      'icon': Icons.kitchen_rounded,
      'color': Color(0xFFF97316),
    },
    {
      'id': 'picnic_scene',
      'title': 'Picnic Scene',
      'description': 'A park scene with people having a picnic and various activities',
      'asset': 'assets/images/speech/picnic_scene.png',
      'icon': Icons.park_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'id': 'market_scene',
      'title': 'Market Scene',
      'description': 'A busy market scene with vendors, shoppers, and various items',
      'asset': 'assets/images/speech/market_scene.png',
      'icon': Icons.storefront_rounded,
      'color': Color(0xFF8B5CF6),
    },
  ];

  // Timing
  final int _viewingDurationSeconds = 30; // Time to look at image
  final int _maxRecordingSeconds = 60; // Max recording time
  int _viewingSeconds = 0;
  int _recordingSeconds = 0;
  double _viewingProgress = 0.0;
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
    _recordingTimer?.cancel();
    _viewingTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _currentImage => _images[_currentTrial];

  void _startViewing() {
    setState(() {
      _currentPhase = PictureDescPhase.viewing;
      _viewingSeconds = 0;
      _viewingProgress = 0.0;
    });

    _viewingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _viewingSeconds++;
        _viewingProgress = _viewingSeconds / _viewingDurationSeconds;
        
        if (_viewingSeconds >= _viewingDurationSeconds) {
          timer.cancel();
          _startRecording();
        }
      });
    });
  }

  void _skipToRecording() {
    _viewingTimer?.cancel();
    _startRecording();
  }

  Future<void> _startRecording() async {
    final imageId = _currentImage['id'];
    final fileName = 'picture_desc_${imageId}_${DateTime.now().millisecondsSinceEpoch}';
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
      _currentPhase = PictureDescPhase.recording;
      _isRecording = true;
      _recordingSeconds = 0;
      _recordingStartTime = DateTime.now();
    });

    _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;

        if (_recordingSeconds >= _maxRecordingSeconds) {
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
      'image_id': _currentImage['id'],
      'image_title': _currentImage['title'],
      'viewing_duration_s': _viewingSeconds,
      'recording_duration_ms': duration,
      'audio_path': audioPath ?? '',
    });

    setState(() {
      _isRecording = false;

      if (_currentTrial < _totalTrials - 1) {
        // Move to next image
        _currentTrial++;
        _currentPhase = PictureDescPhase.instructions;
      } else {
        // All trials completed
        _testData['trials'] = _trialResults;
        _testData['total_duration_ms'] = _trialResults.fold(0, (sum, t) => sum + (t['recording_duration_ms'] as int));
        _testData['completed'] = true;
        _currentPhase = PictureDescPhase.completed;
      }
    });
  }

  Future<void> _retakeRecording() async {
    HapticFeedback.mediumImpact();
    await _audioRecorder.cancelRecording();
    setState(() {
      _trialResults.clear();
      _testData['completed'] = false;
      _testData['trials'] = [];
      _testData['total_duration_ms'] = 0;
      _currentTrial = 0;
      _viewingSeconds = 0;
      _recordingSeconds = 0;
      _viewingProgress = 0.0;
      _currentPhase = PictureDescPhase.instructions;
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
            if (_currentPhase == PictureDescPhase.viewing || 
                _currentPhase == PictureDescPhase.recording)
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
              width: r.w(44),
              height: r.h(44),
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
                  'Picture Description',
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
              color: (_currentImage['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _currentPhase == PictureDescPhase.completed
                      ? Icons.check_circle_rounded
                      : Icons.image_rounded,
                  color: _currentPhase == PictureDescPhase.completed
                      ? greenAccent
                      : _currentImage['color'] as Color,
                  size: r.dp(16),
                ),
                SizedBox(width: r.w(6)),
                Text(
                  _currentPhase == PictureDescPhase.completed
                      ? 'Done'
                      : '${_currentTrial + 1}/$_totalTrials',
                  style: TextStyle(
                    color: _currentPhase == PictureDescPhase.completed
                        ? greenAccent
                        : _currentImage['color'] as Color,
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
      case PictureDescPhase.instructions:
        return 'Image ${_currentTrial + 1}: ${_currentImage['title']}';
      case PictureDescPhase.viewing:
        return 'Study the image carefully';
      case PictureDescPhase.recording:
        return 'Describe what you see';
      case PictureDescPhase.completed:
        return 'All images described';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    double progress = (_currentTrial / _totalTrials);
    if (_currentPhase == PictureDescPhase.viewing) {
      progress += (_viewingProgress * 0.3 / _totalTrials);
    } else if (_currentPhase == PictureDescPhase.recording) {
      progress += (0.3 + (_recordingSeconds / _maxRecordingSeconds) * 0.7) / _totalTrials;
    } else if (_currentPhase == PictureDescPhase.completed) {
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
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [greenAccent, orangeAccent, purpleAccent],
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
      padding: EdgeInsets.all(r.dp(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.dp(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: r.dp(20),
            offset: Offset(r.w(0), r.h(4)),
          ),
        ],
      ),
      child: _buildPhaseContent(r),
    );
  }

  Widget _buildPhaseContent(Responsive r) {
    switch (_currentPhase) {
      case PictureDescPhase.instructions:
        return _buildInstructionsPhase(r);
      case PictureDescPhase.viewing:
        return _buildViewingPhase(r);
      case PictureDescPhase.recording:
        return _buildRecordingPhase(r);
      case PictureDescPhase.completed:
        return _buildCompletedPhase(r);
    }
  }

  Widget _buildInstructionsPhase(Responsive r) {
    final imageColor = _currentImage['color'] as Color;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(10)),
          // Image preview thumbnail
          Container(
            width: r.w(100),
            height: r.h(100),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(20)),
              border: Border.all(color: imageColor.withOpacity(0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              _currentImage['asset'] as String,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  _currentImage['icon'] as IconData,
                  color: imageColor,
                  size: r.dp(40),
                );
              },
            ),
          ),
          SizedBox(height: r.h(20)),
          // Title
          Text(
            'Image ${_currentTrial + 1}: ${_currentImage['title']}',
            style: TextStyle(
              fontSize: r.sp(22),
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: r.h(8)),
          Text(
            _currentImage['description'],
            style: TextStyle(
              fontSize: r.sp(13),
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.h(20)),
          // Instructions card
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(r.dp(14)),
              border: Border.all(color: imageColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(r, Icons.visibility_rounded, 'Study the image for 30 seconds'),
                SizedBox(height: r.h(8)),
                _buildInstructionRow(r, Icons.mic_rounded, 'Then describe everything you see'),
                SizedBox(height: r.h(8)),
                _buildInstructionRow(r, Icons.checklist_rounded, 'Include people, objects, actions'),
              ],
            ),
          ),
          SizedBox(height: r.h(20)),
          // Trial indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalTrials, (index) {
              final isCompleted = index < _currentTrial;
              final isCurrent = index == _currentTrial;
              final trialColor = _images[index]['color'] as Color;
              
              return Container(
                margin: EdgeInsets.symmetric(horizontal: r.w(6)),
                width: isCurrent ? 36 : 28,
                height: isCurrent ? 36 : 28,
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? greenAccent 
                      : (isCurrent ? trialColor : Colors.grey[200]),
                  shape: BoxShape.circle,
                  border: isCurrent 
                      ? Border.all(color: trialColor, width: r.w(3))
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: r.dp(16))
                      : Icon(
                          _images[index]['icon'] as IconData,
                          size: isCurrent ? 18 : 14,
                          color: isCurrent ? Colors.white : Colors.grey[400],
                        ),
                ),
              );
            }),
          ),
          SizedBox(height: r.h(24)),
          // Start button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _startViewing();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: imageColor,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: imageColor.withOpacity(0.4),
                    blurRadius: r.dp(20),
                    offset: Offset(r.w(0), r.h(8)),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: r.dp(22)),
                  SizedBox(width: r.w(8)),
                  Text(
                    _currentTrial == 0 ? 'View Image' : 'Next Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(15),
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

  Widget _buildInstructionRow(Responsive r, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: r.dp(18)),
        SizedBox(width: r.w(10)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: r.sp(12),
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewingPhase(Responsive r) {
    final imageColor = _currentImage['color'] as Color;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(10)),
          // Timer badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(8)),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_rounded, color: imageColor, size: r.dp(18)),
                SizedBox(width: r.w(8)),
                Text(
                  'Study Time: ${_viewingDurationSeconds - _viewingSeconds}s',
                  style: TextStyle(
                    color: imageColor,
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          // Clinical scene image
          Container(
            height: r.h(220),
            width: double.infinity,
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(r.dp(16)),
              border: Border.all(color: imageColor.withOpacity(0.3), width: r.w(2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              _currentImage['asset'] as String,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if image asset not found
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentImage['icon'] as IconData,
                      color: imageColor,
                      size: r.dp(60),
                    ),
                    SizedBox(height: r.h(12)),
                    Text(
                      _currentImage['title'] as String,
                      style: TextStyle(
                        fontSize: r.sp(16),
                        fontWeight: FontWeight.w700,
                        color: imageColor,
                      ),
                    ),
                    SizedBox(height: r.h(4)),
                    Text(
                      'Add image to ${_currentImage['asset']}',
                      style: TextStyle(fontSize: r.sp(11), color: Colors.grey[500]),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: r.h(16)),
          // Progress bar
          Container(
            width: double.infinity,
            height: r.h(6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(r.dp(3)),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _viewingProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: imageColor,
                  borderRadius: BorderRadius.circular(r.dp(3)),
                ),
              ),
            ),
          ),
          SizedBox(height: r.h(16)),
          // Tips
          Container(
            padding: EdgeInsets.all(r.dp(12)),
            decoration: BoxDecoration(
              color: creamBeige.withOpacity(0.5),
              borderRadius: BorderRadius.circular(r.dp(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: orangeAccent, size: r.dp(18)),
                SizedBox(width: r.w(10)),
                Expanded(
                  child: Text(
                    'Notice: people, objects, colors, actions, positions',
                    style: TextStyle(
                      fontSize: r.sp(11),
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          // Skip button
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _skipToRecording();
            },
            child: Text(
              'Ready to describe →',
              style: TextStyle(
                color: imageColor,
                fontSize: r.sp(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingPhase(Responsive r) {
    final imageColor = _currentImage['color'] as Color;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(10)),
          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: r.w(90) + (_pulseController.value * 20),
                height: r.h(90) + (_pulseController.value * 20),
                decoration: BoxDecoration(
                  color: redAccent.withOpacity(0.1 + _pulseController.value * 0.1),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: EdgeInsets.all(r.dp(18)),
                  decoration: BoxDecoration(
                    color: redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: redAccent.withOpacity(0.4),
                        blurRadius: r.dp(20),
                        spreadRadius: r.dp(3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: r.dp(28),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: r.h(20)),
          // Recording text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: r.w(10),
                height: r.h(10),
                decoration: const BoxDecoration(
                  color: redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: r.w(8)),
              Text(
                'Describe the image',
                style: TextStyle(
                  fontSize: r.sp(18),
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: r.h(6)),
          Text(
            'Tell us everything you remember seeing',
            style: TextStyle(
              fontSize: r.sp(12),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: r.h(16)),
          // Timer
          Text(
            _formatTime(_recordingSeconds),
            style: TextStyle(
              fontSize: r.sp(36),
              fontWeight: FontWeight.w300,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: r.h(16)),
          // Waveform
          Container(
            height: r.h(50),
            margin: EdgeInsets.symmetric(horizontal: r.w(10)),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 50),
                  painter: DescriptionWaveformPainter(
                    animation: _waveController.value,
                    color: redAccent,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: r.h(16)),
          // Small image reminder
          Container(
            padding: EdgeInsets.all(r.dp(10)),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_currentImage['icon'] as IconData, color: imageColor, size: r.dp(20)),
                SizedBox(width: r.w(8)),
                Text(
                  _currentImage['title'],
                  style: TextStyle(
                    fontSize: r.sp(12),
                    fontWeight: FontWeight.w600,
                    color: imageColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          // Stop button
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              _stopRecording();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(36), vertical: r.h(12)),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(r.dp(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.white, size: r.dp(20)),
                  SizedBox(width: r.w(8)),
                  Text(
                    'Done Describing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(14),
                      fontWeight: FontWeight.w700,
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

  Widget _buildCompletedPhase(Responsive r) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: r.h(10)),
          // Success icon
          Container(
            width: r.w(80),
            height: r.h(80),
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: greenAccent,
              size: r.dp(45),
            ),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'All Images Described!',
            style: TextStyle(
              fontSize: r.sp(22),
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: r.h(6)),
          Text(
            'Your descriptions have been recorded',
            style: TextStyle(
              fontSize: r.sp(13),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: r.h(20)),
          // Results summary
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(r.dp(14)),
            ),
            child: Column(
              children: [
                ...List.generate(_trialResults.length, (index) {
                  final trial = _trialResults[index];
                  final imageColor = _images[index]['color'] as Color;
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < _trialResults.length - 1 ? 10 : 0),
                    child: Row(
                      children: [
                        Container(
                          width: r.w(32),
                          height: r.h(32),
                          decoration: BoxDecoration(
                            color: imageColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _images[index]['icon'] as IconData,
                            size: r.dp(16),
                            color: imageColor,
                          ),
                        ),
                        SizedBox(width: r.w(10)),
                        Expanded(
                          child: Text(
                            trial['image_title'],
                            style: TextStyle(
                              fontSize: r.sp(13),
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '${(trial['recording_duration_ms'] / 1000).toStringAsFixed(0)}s',
                          style: TextStyle(
                            fontSize: r.sp(13),
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: r.w(6)),
                        Icon(
                          Icons.check_circle_rounded,
                          color: greenAccent,
                          size: r.dp(18),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: r.h(20)),
          // Continue button
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: greenAccent.withOpacity(0.4),
                    blurRadius: r.dp(20),
                    offset: Offset(r.w(0), r.h(8)),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: r.dp(20)),
                  SizedBox(width: r.w(8)),
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(15),
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
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
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
          SizedBox(height: r.h(10)),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(Responsive r) {
    final imageColor = _currentImage['color'] as Color;
    
    return Container(
      margin: EdgeInsets.all(r.dp(20)),
      padding: EdgeInsets.all(r.dp(14)),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(r.dp(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniMetric(r, 
            _currentPhase == PictureDescPhase.viewing ? 'VIEWING' : 'RECORDING',
            _currentPhase == PictureDescPhase.viewing 
                ? '${_viewingSeconds}s'
                : _formatTime(_recordingSeconds),
            _currentPhase == PictureDescPhase.viewing ? blueAccent : redAccent,
          ),
          Container(
            width: r.w(1),
            height: r.h(36),
            color: Colors.white.withOpacity(0.1),
          ),
          _buildMiniMetric(r, 'IMAGE', '${_currentTrial + 1}/$_totalTrials', imageColor),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(Responsive r, String label, String value, Color color) {
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
              width: r.w(8),
              height: r.h(8),
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
                fontSize: r.sp(16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

// Waveform painter
class DescriptionWaveformPainter extends CustomPainter {
  final double animation;
  final Color color;

  DescriptionWaveformPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final barCount = 25;
    final barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;
      
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
  bool shouldRepaint(DescriptionWaveformPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}