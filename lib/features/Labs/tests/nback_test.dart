import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Test phases
enum NBackPhase { instructions, practice, test, completed }

class NBackTestScreen extends StatefulWidget {
  const NBackTestScreen({super.key});

  @override
  State<NBackTestScreen> createState() => _NBackTestScreenState();
}

class _NBackTestScreenState extends State<NBackTestScreen>
    with TickerProviderStateMixin {
  
  NBackPhase _currentPhase = NBackPhase.instructions;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _gridController;

  // ==================== ADAPTIVE CONFIGURATION ====================
  // Modified: _nBack is now a variable, starting at 1
  int _nBack = 1; 
  
  // New: Block configuration
  int _currentBlock = 1;
  final int _totalBlocks = 3;
  final int _trialsPerBlock = 15; // Trials per difficulty level
  int _currentTrial = 0; // <--- ADD THIS LINE
  // Practice settings
  final int _practiceTrials = 8;
  bool _isPractice = true;

  // Stimulus timing
  final int _stimulusDurationMs = 500;
  final int _interStimulusIntervalMs = 2000;

  // Current state
  int? _currentPosition; // 0-8 for 3x3 grid
  List<int> _sequence = [];
  bool _showingStimulus = false;
  bool _canRespond = false;
  bool _responded = false;
  bool? _lastResponseCorrect;
  DateTime? _stimulusStartTime;

  // Results tracking
  int _hits = 0;
  int _misses = 0;
  int _falseAlarms = 0;
  int _correctRejections = 0;
  List<int> _reactionTimes = [];
  final List<Map<String, dynamic>> _trialResults = [];
  
  // New: Track block-specific accuracy for adaptation
  int _blockHits = 0;
  int _blockMisses = 0;
  int _blockFalseAlarms = 0;
  int _blockCorrectRejections = 0;

  // Timers
  Timer? _stimulusTimer;
  Timer? _responseWindowTimer;

  // Random generator
  final math.Random _random = math.Random();

  // Design colors (Same as before)
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color orangeAccent = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
    _gridController.dispose();
    _stimulusTimer?.cancel();
    _responseWindowTimer?.cancel();
    super.dispose();
  }

  // ==================== UPDATED LOGIC ====================

  void _generateSequence(int length) {
    _sequence = [];
    final positions = List.generate(9, (i) => i); 
    
    for (int i = 0; i < length; i++) {
      // Use current _nBack variable
      if (i >= _nBack && _random.nextDouble() < 0.3) {
        _sequence.add(_sequence[i - _nBack]);
      } else {
        int pos;
        do {
          pos = positions[_random.nextInt(positions.length)];
        } while (i >= _nBack && pos == _sequence[i - _nBack]);
        _sequence.add(pos);
      }
    }
  }

  bool _isMatch() {
    // Current trial index relative to the sequence start
    // Note: In blocks, we reset the sequence, so index is just the trial index
    if (_currentTrial < _nBack) return false;
    return _sequence[_currentTrial] == _sequence[_currentTrial - _nBack];
  }

  void _startPractice() {
    _nBack = 1; // Practice always starts at 1-back
    _generateSequence(_practiceTrials);
    setState(() {
      _currentPhase = NBackPhase.practice;
      _isPractice = true;
      _currentTrial = 0;
      _resetMetrics();
    });
    _showNextStimulus();
  }

  void _startTest() {
    _nBack = 1; // Test starts at 1-back and adapts
    _currentBlock = 1;
    _generateSequence(_trialsPerBlock); // Generate just for this block
    
    setState(() {
      _currentPhase = NBackPhase.test;
      _isPractice = false;
      _currentTrial = 0;
      _resetMetrics();
      _resetBlockMetrics();
      _reactionTimes = [];
      _trialResults.clear();
    });
    _showNextStimulus();
  }

  void _resetMetrics() {
    _hits = 0;
    _misses = 0;
    _falseAlarms = 0;
    _correctRejections = 0;
  }
  
  void _resetBlockMetrics() {
    _blockHits = 0;
    _blockMisses = 0;
    _blockFalseAlarms = 0;
    _blockCorrectRejections = 0;
  }

  void _showNextStimulus() {
    setState(() {
      _currentPosition = _sequence[_currentTrial];
      _showingStimulus = true;
      _canRespond = true;
      _responded = false;
      _lastResponseCorrect = null;
      _stimulusStartTime = DateTime.now();
    });

    _pulseController.forward(from: 0);
    _gridController.forward(from: 0);

    _stimulusTimer = Timer(Duration(milliseconds: _stimulusDurationMs), () {
      if (mounted) {
        setState(() {
          _showingStimulus = false;
        });
      }
    });

    _responseWindowTimer = Timer(Duration(milliseconds: _interStimulusIntervalMs), () {
      if (mounted) _evaluateResponse();
    });
  }

  void _handleMatchPress() {
    if (!_canRespond || _responded) return;

    HapticFeedback.mediumImpact();
    final reactionTime = DateTime.now().difference(_stimulusStartTime!).inMilliseconds;

    setState(() {
      _responded = true;
      _canRespond = false;
      
      if (_isMatch()) {
        _hits++;
        _blockHits++;
        _lastResponseCorrect = true;
      } else {
        _falseAlarms++;
        _blockFalseAlarms++;
        _lastResponseCorrect = false;
      }

      if (!_isPractice) {
        _reactionTimes.add(reactionTime);
      }
    });
  }

  void _evaluateResponse() {
    final wasMatch = _isMatch();
    
    if (!_responded) {
      if (wasMatch) {
        _misses++;
        _blockMisses++;
        _lastResponseCorrect = false;
      } else {
        _correctRejections++;
        _blockCorrectRejections++;
        _lastResponseCorrect = true;
      }
    }

    if (!_isPractice) {
      _trialResults.add({
        'trial': _trialResults.length + 1,
        'block': _currentBlock,
        'n_back_level': _nBack,
        'position': _currentPosition,
        'was_match': wasMatch,
        'responded': _responded,
        'correct': _lastResponseCorrect ?? false,
        'reaction_time_ms': _responded && _reactionTimes.isNotEmpty ? _reactionTimes.last : null,
      });
    }

    setState(() {
      _currentTrial++; // Increment local trial counter
      _canRespond = false;
    });

    // Check if block or practice is finished
    final maxTrials = _isPractice ? _practiceTrials : _trialsPerBlock;
    
    if (_currentTrial >= maxTrials) {
      if (_isPractice) {
        // End Practice
        Future.delayed(const Duration(milliseconds: 500), _startTest);
      } else {
        // End of a Test Block - Handle Adaptation
        _handleBlockCompletion();
      }
    } else {
      // Continue Block
      Future.delayed(const Duration(milliseconds: 300), _showNextStimulus);
    }
  }

  // ==================== NEW: ADAPTIVE LOGIC ====================
  
  void _handleBlockCompletion() {
    if (_currentBlock >= _totalBlocks) {
      // All blocks done
      setState(() {
        _currentPhase = NBackPhase.completed;
      });
      return;
    }

    // Calculate accuracy for this specific block
    final blockTotal = _blockHits + _blockMisses + _blockFalseAlarms + _blockCorrectRejections;
    final blockAccuracy = (_blockHits + _blockCorrectRejections) / blockTotal;
    
    String levelMessage = "Keeping at $_nBack-Back";
    Color levelColor = blueAccent;
    IconData levelIcon = Icons.remove; // No change

    // ADAPTATION LOGIC
    int newNBack = _nBack;
    
    if (blockAccuracy > 0.8) {
      // Level Up
      newNBack++;
      levelMessage = "Level Up! Now ${newNBack}-Back";
      levelColor = greenAccent;
      levelIcon = Icons.arrow_upward;
    } else if (blockAccuracy < 0.5 && _nBack > 1) {
      // Level Down
      newNBack--;
      levelMessage = "Easing down. Now ${newNBack}-Back";
      levelColor = orangeAccent;
      levelIcon = Icons.arrow_downward;
    }

    // Show Level Change Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(levelIcon, color: levelColor),
            const SizedBox(width: 10),
            Text('Block ${_currentBlock} Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Accuracy: ${(blockAccuracy * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 10),
            Text(
              levelMessage, 
              style: TextStyle(color: levelColor, fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ],
        ),
      ),
    );

    // Prepare next block after delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context, rootNavigator: true).pop(); // Close dialog
      
      setState(() {
        _nBack = newNBack;
        _currentBlock++;
        _currentTrial = 0; // Reset trial counter for new block
        _resetBlockMetrics();
      });
      
      // Generate NEW sequence for the new difficulty
      _generateSequence(_trialsPerBlock);
      _showNextStimulus();
    });
  }

  Map<String, dynamic> _getTestData() {
    final totalMatches = _hits + _misses;
    final totalTrials = _trialsPerBlock * _totalBlocks; // Approximation
    final accuracy = (_hits + _correctRejections) / _trialResults.length; // Use actual count
    final avgRT = _reactionTimes.isNotEmpty 
        ? _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length 
        : 0.0;
    
    return {
      'test_type': 'nback_adaptive',
      'max_n_reached': _nBack, // The level they ended on
      'total_trials': _trialResults.length,
      'hits': _hits,
      'misses': _misses,
      'false_alarms': _falseAlarms,
      'correct_rejections': _correctRejections,
      'accuracy': accuracy,
      'avg_reaction_time_ms': avgRT,
      'trials': _trialResults,
      'completed': true,
    };
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _stimulusTimer?.cancel();
    _responseWindowTimer?.cancel();
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
            if (_currentPhase == NBackPhase.practice || 
                _currentPhase == NBackPhase.test)
              _buildBottomSection(),
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
                  'N-Back Memory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // DYNAMIC LEVEL BADGE
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Container(
              key: ValueKey(_nBack), // Animate when N changes
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: orangeAccent.withOpacity(0.3)),
              ),
              child: Text(
                '$_nBack-Back', // Shows current Level
                style: const TextStyle(
                  color: orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case NBackPhase.instructions:
        return 'Read instructions carefully';
      case NBackPhase.practice:
        return 'Practice round - Trial ${_currentTrial + 1}/$_practiceTrials';
      case NBackPhase.test:
        // Shows Block info
        return 'Block $_currentBlock/$_totalBlocks - Trial ${_currentTrial + 1}/$_trialsPerBlock';
      case NBackPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar() {
    double progress = 0;
    if (_currentPhase == NBackPhase.practice) {
      progress = _currentTrial / _practiceTrials * 0.1;
    } else if (_currentPhase == NBackPhase.test) {
      // Calculate total progress based on blocks
      int totalTrialsCompleted = ((_currentBlock - 1) * _trialsPerBlock) + _currentTrial;
      int totalTrialsTotal = _totalBlocks * _trialsPerBlock;
      progress = 0.1 + (totalTrialsCompleted / totalTrialsTotal * 0.9);
    } else if (_currentPhase == NBackPhase.completed) {
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
            gradient: const LinearGradient(colors: [orangeAccent, redAccent]),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  // ... (Rest of UI widgets: _buildContent, _buildInstructionsPhase, etc. remain the same)
  
  // NOTE: Ensure _buildTestPhase uses _nBack in the hint text:
  Widget _buildTestPhase() {
    return Column(
      children: [
        // Feedback indicator (Same as before)
        if (_lastResponseCorrect != null)
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _lastResponseCorrect! 
                  ? greenAccent.withOpacity(0.1) 
                  : redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _lastResponseCorrect! ? Icons.check : Icons.close,
                  color: _lastResponseCorrect! ? greenAccent : redAccent,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _lastResponseCorrect! ? 'Correct!' : 'Wrong',
                  style: TextStyle(
                    color: _lastResponseCorrect! ? greenAccent : redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isPractice ? Colors.orange.withOpacity(0.1) : blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isPractice ? '🎯 Practice (1-Back)' : '📝 Test (Adaptive)',
              style: TextStyle(
                color: _isPractice ? Colors.orange : blueAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 20),
        // Main grid
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
                child: _buildGrid(),
              ),
            ),
          ),
        ),
        // DYNAMIC HINT
        if (_currentTrial >= _nBack)
          Text(
            'Same as $_nBack positions ago?',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ... (_buildGrid, _buildBottomSection, _buildMetricsBar, etc. remain unchanged)

  // Just ensure _buildCompletedPhase shows the correct final N level
  Widget _buildCompletedPhase() {
    final data = _getTestData();
    final accuracy = (data['accuracy'] * 100).toStringAsFixed(0);
    final maxN = data['max_n_reached'];

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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildResultRow('Highest Level Reached', '$maxN-Back'), // New Stat
                const Divider(height: 20),
                _buildResultRow('Overall Accuracy', '$accuracy%'),
                const Divider(height: 20),
                _buildResultRow('Hits / Misses', '$_hits / $_misses'),
                const Divider(height: 20),
                _buildResultRow('False Alarms', '$_falseAlarms'),
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
          const SizedBox(height: 10),
        ],
      ),
    );
  }
  
  // Helper for UI
  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
      ],
    );
  }

  // Grid builder
  Widget _buildGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final isHighlighted = _showingStimulus && index == _currentPosition;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHighlighted ? orangeAccent : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted ? orangeAccent : Colors.grey[300]!,
              width: 2,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: orangeAccent.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Match button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: _canRespond ? _handleMatchPress : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _canRespond 
                    ? (_responded ? Colors.grey : orangeAccent) 
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
                boxShadow: _canRespond && !_responded
                    ? [
                        BoxShadow(
                          color: orangeAccent.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _responded ? Icons.check : Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _responded ? 'Responded!' : 'MATCH',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Metrics bar
        _buildMetricsBar(),
      ],
    );
  }

  Widget _buildMetricsBar() {
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
          _buildMiniMetric('HITS', '$_hits', greenAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('MISSES', '$_misses', redAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('FALSE', '$_falseAlarms', orangeAccent),
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
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
  
  // Needed for instructions phase - copied from original
  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.grid_3x3_rounded, color: orangeAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Adaptive N-Back',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Test adjusts to your skill level',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          // ... (Rest of instructions UI same as original)
           const SizedBox(height: 20),
          // Mini grid example
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Watch the grid:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: _buildMiniGrid(4), // Example position
                ),
                const SizedBox(height: 12),
                Text(
                  'Start at 1-Back (same as previous).\nIf you do well, it gets harder!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startPractice,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: orangeAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: orangeAccent.withOpacity(0.4),
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
                    'Start Practice',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
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

  Widget _buildMiniGrid(int highlightPosition) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final isHighlighted = index == highlightPosition;
        return Container(
          decoration: BoxDecoration(
            color: isHighlighted ? orangeAccent : Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
        );
      },
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
      case NBackPhase.instructions:
        return _buildInstructionsPhase();
      case NBackPhase.practice:
      case NBackPhase.test:
        return _buildTestPhase();
      case NBackPhase.completed:
        return _buildCompletedPhase();
    }
  }
}