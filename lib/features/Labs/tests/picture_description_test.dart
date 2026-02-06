import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  
  // Images to describe (using placeholder descriptions - actual images would be assets)
  final List<Map<String, dynamic>> _images = [
    {
      'id': 'park_scene',
      'title': 'Park Scene',
      'description': 'A busy park with people, trees, and activities',
      'icon': Icons.park_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'id': 'kitchen_scene', 
      'title': 'Kitchen Scene',
      'description': 'A kitchen with cooking activities and items',
      'icon': Icons.kitchen_rounded,
      'color': Color(0xFFF97316),
    },
    {
      'id': 'street_scene',
      'title': 'Street Scene', 
      'description': 'A street with buildings, vehicles, and people',
      'icon': Icons.location_city_rounded,
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

    _viewingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  void _startRecording() {
    setState(() {
      _currentPhase = PictureDescPhase.recording;
      _isRecording = true;
      _recordingSeconds = 0;
      _recordingStartTime = DateTime.now();
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
        
        if (_recordingSeconds >= _maxRecordingSeconds) {
          _stopRecording();
        }
      });
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    
    final duration = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
    
    // Save trial result
    _trialResults.add({
      'image_id': _currentImage['id'],
      'image_title': _currentImage['title'],
      'viewing_duration_s': _viewingSeconds,
      'recording_duration_ms': duration,
      'audio_path': 'recordings/picture_desc_${_currentImage['id']}_${DateTime.now().millisecondsSinceEpoch}.wav',
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
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: _buildTestArea(),
            ),
            if (_currentPhase == PictureDescPhase.viewing || 
                _currentPhase == PictureDescPhase.recording)
              _buildMetricsBar(),
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
                  'Picture Description',
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
          // Trial counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_currentImage['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
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
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentPhase == PictureDescPhase.completed
                      ? 'Done'
                      : '${_currentTrial + 1}/$_totalTrials',
                  style: TextStyle(
                    color: _currentPhase == PictureDescPhase.completed
                        ? greenAccent
                        : _currentImage['color'] as Color,
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

  Widget _buildProgressBar() {
    double progress = (_currentTrial / _totalTrials);
    if (_currentPhase == PictureDescPhase.viewing) {
      progress += (_viewingProgress * 0.3 / _totalTrials);
    } else if (_currentPhase == PictureDescPhase.recording) {
      progress += (0.3 + (_recordingSeconds / _maxRecordingSeconds) * 0.7) / _totalTrials;
    } else if (_currentPhase == PictureDescPhase.completed) {
      progress = 1.0;
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
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [greenAccent, orangeAccent, purpleAccent],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildTestArea() {
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
      case PictureDescPhase.instructions:
        return _buildInstructionsPhase();
      case PictureDescPhase.viewing:
        return _buildViewingPhase();
      case PictureDescPhase.recording:
        return _buildRecordingPhase();
      case PictureDescPhase.completed:
        return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    final imageColor = _currentImage['color'] as Color;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Image icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _currentImage['icon'] as IconData,
              color: imageColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            'Image ${_currentTrial + 1}: ${_currentImage['title']}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentImage['description'],
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Instructions card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: imageColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.visibility_rounded, 'Study the image for 30 seconds'),
                const SizedBox(height: 8),
                _buildInstructionRow(Icons.mic_rounded, 'Then describe everything you see'),
                const SizedBox(height: 8),
                _buildInstructionRow(Icons.checklist_rounded, 'Include people, objects, actions'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Trial indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalTrials, (index) {
              final isCompleted = index < _currentTrial;
              final isCurrent = index == _currentTrial;
              final trialColor = _images[index]['color'] as Color;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isCurrent ? 36 : 28,
                height: isCurrent ? 36 : 28,
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
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Icon(
                          _images[index]['icon'] as IconData,
                          size: isCurrent ? 18 : 14,
                          color: isCurrent ? Colors.white : Colors.grey[400],
                        ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Start button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              _startViewing();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: imageColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: imageColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _currentTrial == 0 ? 'View Image' : 'Next Image',
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

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewingPhase() {
    final imageColor = _currentImage['color'] as Color;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Timer badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_rounded, color: imageColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Study Time: ${_viewingDurationSeconds - _viewingSeconds}s',
                  style: TextStyle(
                    color: imageColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Image placeholder (would be actual image in production)
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: imageColor.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _currentImage['icon'] as IconData,
                  color: imageColor,
                  size: 60,
                ),
                const SizedBox(height: 12),
                Text(
                  _currentImage['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: imageColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '(Image would appear here)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
              widthFactor: _viewingProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: imageColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: creamBeige.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: orangeAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Notice: people, objects, colors, actions, positions',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingPhase() {
    final imageColor = _currentImage['color'] as Color;
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 90 + (_pulseController.value * 20),
                height: 90 + (_pulseController.value * 20),
                decoration: BoxDecoration(
                  color: redAccent.withOpacity(0.1 + _pulseController.value * 0.1),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  margin: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: redAccent.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          // Recording text
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
                'Describe the image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us everything you remember seeing',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          // Timer
          Text(
            _formatTime(_recordingSeconds),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w300,
              color: Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          // Waveform
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 10),
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
          const SizedBox(height: 16),
          // Small image reminder
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: imageColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_currentImage['icon'] as IconData, color: imageColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _currentImage['title'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: imageColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stop button
          GestureDetector(
            onTap: () {
              HapticFeedback.heavyImpact();
              _stopRecording();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Done Describing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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

  Widget _buildCompletedPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Success icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: greenAccent,
              size: 45,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'All Images Described!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your descriptions have been recorded',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          // Results summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: imageColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _images[index]['icon'] as IconData,
                            size: 16,
                            color: imageColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            trial['image_title'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '${(trial['recording_duration_ms'] / 1000).toStringAsFixed(0)}s',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: greenAccent,
                          size: 18,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
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

  Widget _buildMetricsBar() {
    final imageColor = _currentImage['color'] as Color;
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniMetric(
            _currentPhase == PictureDescPhase.viewing ? 'VIEWING' : 'RECORDING',
            _currentPhase == PictureDescPhase.viewing 
                ? '${_viewingSeconds}s'
                : _formatTime(_recordingSeconds),
            _currentPhase == PictureDescPhase.viewing ? blueAccent : redAccent,
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.white.withOpacity(0.1),
          ),
          _buildMiniMetric('IMAGE', '${_currentTrial + 1}/$_totalTrials', imageColor),
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
                fontSize: 16,
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