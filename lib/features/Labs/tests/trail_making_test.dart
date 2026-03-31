import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/responsive.dart';

enum TMTPhase { instructions, partA, partB, completed }

class TrailMakingTestScreen extends StatefulWidget {
  const TrailMakingTestScreen({super.key});

  @override
  State<TrailMakingTestScreen> createState() => _TrailMakingTestScreenState();
}

class _TrailMakingTestScreenState extends State<TrailMakingTestScreen>
    with TickerProviderStateMixin {
  TMTPhase _currentPhase = TMTPhase.instructions;

  late AnimationController _pulseController;

  // Circle positions (generated on layout)
  List<Offset> _circlePositions = [];
  List<String> _circleLabels = [];
  int _currentTarget = 0;
  bool _hasError = false;

  // Trail path (connected circles)
  List<Offset> _trailPath = [];
  // Current finger position for live line
  Offset? _fingerPosition;

  // Timing
  DateTime? _startTime;
  DateTime? _endTime;
  final Stopwatch _stopwatch = Stopwatch();

  // Results
  Map<String, dynamic> _partAResults = {};
  Map<String, dynamic> _partBResults = {};
  int _errorsA = 0;
  int _errorsB = 0;

  // Pen trajectory data for backend kinematic analysis
  final List<Map<String, dynamic>> _trajectoryPoints = [];

  // Circle layout
  static const int _partACount = 25;
  static const int _partBCount = 24; // 1-A-2-B-...-12-L
  static const double _circleRadius = 20;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color softLavender = Color(0xFFE8DFF0);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    super.dispose();
  }

  void _startPartA() {
    setState(() {
      _currentPhase = TMTPhase.partA;
      _currentTarget = 0;
      _trailPath = [];
      _fingerPosition = null;
      _errorsA = 0;
      _trajectoryPoints.clear();
      _hasError = false;
      _circlePositions = [];
      _distractorPositions = [];
    });
  }

  void _startPartB() {
    setState(() {
      _currentPhase = TMTPhase.partB;
      _currentTarget = 0;
      _trailPath = [];
      _fingerPosition = null;
      _errorsB = 0;
      _trajectoryPoints.clear();
      _hasError = false;
      _circlePositions = [];
      _distractorPositions = [];
    });
  }

  // Distractor circles (greyed out, not part of sequence)
  List<Offset> _distractorPositions = [];

  void _generateCirclePositions(Size canvasSize) {
    // TRUE randomization each session — prevents memorization across sessions
    // Uses current timestamp so every attempt has a unique layout
    final seed = DateTime.now().microsecondsSinceEpoch +
        (_currentPhase == TMTPhase.partA ? 0 : 999999);
    final rng = math.Random(seed);
    final count = _currentPhase == TMTPhase.partA ? _partACount : _partBCount;

    // Generate labels
    if (_currentPhase == TMTPhase.partA) {
      _circleLabels = List.generate(count, (i) => '${i + 1}');
    } else {
      // Part B: 1, A, 2, B, 3, C, ... 12, L
      _circleLabels = [];
      for (int i = 0; i < 12; i++) {
        _circleLabels.add('${i + 1}');
        _circleLabels.add(String.fromCharCode(65 + i)); // A=65
      }
    }

    // Place circles with minimum distance constraint
    _circlePositions = [];
    final margin = _circleRadius * 2.5;
    final maxW = canvasSize.width - margin * 2;
    final maxH = canvasSize.height - margin * 2;

    for (int i = 0; i < count; i++) {
      Offset pos;
      int attempts = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * maxW,
          margin + rng.nextDouble() * maxH,
        );
        attempts++;
      } while (_tooClose(pos) && attempts < 100);
      _circlePositions.add(pos);
    }

    // Add distractor circles to prevent pattern recognition
    // These are numbered/lettered circles that are NOT part of the sequence
    // They force visual search rather than spatial memorization
    _distractorPositions = [];
    final distractorCount = _currentPhase == TMTPhase.partA ? 5 : 4;
    for (int i = 0; i < distractorCount; i++) {
      Offset pos;
      int attempts = 0;
      do {
        pos = Offset(
          margin + rng.nextDouble() * maxW,
          margin + rng.nextDouble() * maxH,
        );
        attempts++;
      } while ((_tooClose(pos) || _tooCloseToDistractors(pos)) && attempts < 100);
      _distractorPositions.add(pos);
    }
  }

  bool _tooClose(Offset pos) {
    for (var existing in _circlePositions) {
      if ((pos - existing).distance < _circleRadius * 3) return true;
    }
    return false;
  }

  bool _tooCloseToDistractors(Offset pos) {
    for (var existing in _distractorPositions) {
      if ((pos - existing).distance < _circleRadius * 3) return true;
    }
    // Also check against real circles
    for (var existing in _circlePositions) {
      if ((pos - existing).distance < _circleRadius * 3) return true;
    }
    return false;
  }

  void _onCircleTapped(int index) {
    if (index == _currentTarget) {
      // Correct tap
      HapticFeedback.lightImpact();
      final now = DateTime.now();
      if (_currentTarget == 0) {
        _startTime = now;
        _stopwatch.start();
      }

      setState(() {
        _trailPath.add(_circlePositions[index]);
        _currentTarget++;
        _hasError = false;
      });

      // Record trajectory point
      _trajectoryPoints.add({
        'x': _circlePositions[index].dx,
        'y': _circlePositions[index].dy,
        'time_ms': _stopwatch.elapsedMilliseconds,
        'event': 'correct_tap',
        'target_index': index,
      });

      // Check if part is complete
      final totalCircles = _currentPhase == TMTPhase.partA ? _partACount : _partBCount;
      if (_currentTarget >= totalCircles) {
        _endTime = DateTime.now();
        _stopwatch.stop();
        _finishPart();
      }
    } else {
      // Error
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
      });
      if (_currentPhase == TMTPhase.partA) {
        _errorsA++;
      } else {
        _errorsB++;
      }

      _trajectoryPoints.add({
        'x': _circlePositions[index].dx,
        'y': _circlePositions[index].dy,
        'time_ms': _stopwatch.elapsedMilliseconds,
        'event': 'error_tap',
        'target_index': index,
        'expected_index': _currentTarget,
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _fingerPosition = details.localPosition;
    });

    // Record movement trajectory for kinematic analysis
    if (_stopwatch.isRunning) {
      _trajectoryPoints.add({
        'x': details.localPosition.dx,
        'y': details.localPosition.dy,
        'time_ms': _stopwatch.elapsedMilliseconds,
        'event': 'move',
      });
    }

    // Check if finger is over the target circle
    if (_currentTarget < _circlePositions.length) {
      final targetPos = _circlePositions[_currentTarget];
      if ((details.localPosition - targetPos).distance < _circleRadius * 1.5) {
        _onCircleTapped(_currentTarget);
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _fingerPosition = null;
    });
  }

  void _finishPart() {
    final elapsedMs = _endTime!.difference(_startTime!).inMilliseconds;

    if (_currentPhase == TMTPhase.partA) {
      _partAResults = {
        'time_ms': elapsedMs,
        'time_seconds': elapsedMs / 1000.0,
        'errors': _errorsA,
        'circles_completed': _partACount,
        'trajectory': List.from(_trajectoryPoints),
      };
      _stopwatch.reset();
      Future.delayed(const Duration(milliseconds: 800), _startPartB);
    } else {
      _partBResults = {
        'time_ms': elapsedMs,
        'time_seconds': elapsedMs / 1000.0,
        'errors': _errorsB,
        'circles_completed': _partBCount,
        'trajectory': List.from(_trajectoryPoints),
      };
      _stopwatch.reset();
      setState(() {
        _currentPhase = TMTPhase.completed;
      });
    }
  }

  Map<String, dynamic> _getTestData() {
    final timeA = (_partAResults['time_seconds'] ?? 0).toDouble();
    final timeB = (_partBResults['time_seconds'] ?? 0).toDouble();

    return {
      'test_type': 'trail_making',
      'part_a': _partAResults,
      'part_b': _partBResults,
      'tmt_a_time': timeA,
      'tmt_b_time': timeB,
      'tmt_ba_ratio': timeA > 0 ? timeB / timeA : 0,
      'errors_a': _errorsA,
      'errors_b': _errorsB,
      'completed': true,
    };
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
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
                  'Trail Making Test',
                  style: TextStyle(fontSize: r.sp(20), fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildStatusBadge(r),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Responsive r) {
    Color color;
    String text;
    IconData icon;

    switch (_currentPhase) {
      case TMTPhase.instructions:
        color = orangeAccent;
        text = 'Ready';
        icon = Icons.route_rounded;
        break;
      case TMTPhase.partA:
        color = blueAccent;
        text = 'Part A';
        icon = Icons.looks_one_rounded;
        break;
      case TMTPhase.partB:
        color = purpleAccent;
        text = 'Part B';
        icon = Icons.looks_two_rounded;
        break;
      case TMTPhase.completed:
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
          Text(text, style: TextStyle(color: color, fontSize: r.sp(12), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case TMTPhase.instructions:
        return 'Read instructions carefully';
      case TMTPhase.partA:
        return 'Connect numbers in order: 1-2-3...';
      case TMTPhase.partB:
        return 'Alternate: 1-A-2-B-3-C...';
      case TMTPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    double progress = 0;
    switch (_currentPhase) {
      case TMTPhase.instructions:
        progress = 0;
        break;
      case TMTPhase.partA:
        progress = 0.2;
        break;
      case TMTPhase.partB:
        progress = 0.6;
        break;
      case TMTPhase.completed:
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
            gradient: const LinearGradient(colors: [blueAccent, purpleAccent]),
            borderRadius: BorderRadius.circular(r.dp(3)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Responsive r) {
    return Container(
      margin: EdgeInsets.all(r.dp(20)),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.dp(24)),
        child: _buildPhaseContent(r),
      ),
    );
  }

  Widget _buildPhaseContent(Responsive r) {
    switch (_currentPhase) {
      case TMTPhase.instructions:
        return _buildInstructionsPhase(r);
      case TMTPhase.partA:
      case TMTPhase.partB:
        return _buildTestPhase(r);
      case TMTPhase.completed:
        return _buildCompletedPhase(r);
    }
  }

  Widget _buildInstructionsPhase(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.dp(20)),
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
            child: Icon(Icons.route_rounded, color: orangeAccent, size: r.dp(40)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Trail Making Test',
            style: TextStyle(fontSize: r.sp(24), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Assess processing speed and executive function',
            style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
          ),
          SizedBox(height: r.h(24)),
          // Part A info
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(r.dp(14)),
              border: Border.all(color: blueAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(4)),
                      decoration: BoxDecoration(
                        color: blueAccent,
                        borderRadius: BorderRadius.circular(r.dp(8)),
                      ),
                      child: Text('Part A', style: TextStyle(color: Colors.white, fontSize: r.sp(12), fontWeight: FontWeight.w700)),
                    ),
                    SizedBox(width: r.w(8)),
                    Text('Numbers only', style: TextStyle(fontSize: r.sp(13), color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: r.h(8)),
                Text(
                  'Connect circles in numerical order: 1 → 2 → 3 → ... → 25',
                  style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(12)),
          // Part B info
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: purpleAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(r.dp(14)),
              border: Border.all(color: purpleAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(4)),
                      decoration: BoxDecoration(
                        color: purpleAccent,
                        borderRadius: BorderRadius.circular(r.dp(8)),
                      ),
                      child: Text('Part B', style: TextStyle(color: Colors.white, fontSize: r.sp(12), fontWeight: FontWeight.w700)),
                    ),
                    SizedBox(width: r.w(8)),
                    Text('Numbers + Letters', style: TextStyle(fontSize: r.sp(13), color: Colors.grey[700], fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: r.h(8)),
                Text(
                  'Alternate between numbers and letters: 1 → A → 2 → B → 3 → C ...',
                  style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(r.dp(14)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.speed, 'Work as quickly and accurately as possible', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.touch_app, 'Tap or drag through each circle in order', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.error_outline, 'Errors are recorded but you can continue', r),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _startPartA,
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
                  Text('Start Test', style: TextStyle(color: Colors.white, fontSize: r.sp(15), fontWeight: FontWeight.w700)),
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

  Widget _buildTestPhase(Responsive r) {
    final isPartA = _currentPhase == TMTPhase.partA;
    final color = isPartA ? blueAccent : purpleAccent;
    final partLabel = isPartA ? 'PART A: Numbers' : 'PART B: Numbers + Letters';
    final errors = isPartA ? _errorsA : _errorsB;
    final total = isPartA ? _partACount : _partBCount;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isPartA ? Icons.looks_one_rounded : Icons.looks_two_rounded, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(partLabel, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                children: [
                  if (_hasError)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Wrong!', style: TextStyle(color: redAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(width: 8),
                  Text('$_currentTarget/$total', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                  if (errors > 0) ...[
                    const SizedBox(width: 8),
                    Text('($errors err)', style: TextStyle(color: redAccent, fontSize: 11)),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Next target hint (hidden — user must find it)
        if (_currentTarget < _circleLabels.length)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Tap the next in sequence',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500]),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              if (_circlePositions.isEmpty || _circlePositions.length != (_currentPhase == TMTPhase.partA ? _partACount : _partBCount)) {
                _generateCirclePositions(canvasSize);
              }

              return GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: TMTCanvasPainter(
                    circlePositions: _circlePositions,
                    circleLabels: _circleLabels,
                    currentTarget: _currentTarget,
                    trailPath: _trailPath,
                    fingerPosition: _fingerPosition,
                    circleRadius: _circleRadius,
                    accentColor: color,
                    hasError: _hasError,
                    distractorPositions: _distractorPositions,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedPhase(Responsive r) {
    final timeA = (_partAResults['time_seconds'] ?? 0).toDouble();
    final timeB = (_partBResults['time_seconds'] ?? 0).toDouble();
    final ratio = timeA > 0 ? timeB / timeA : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
          const Text('Test Completed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          // Part A results
          _buildPartResultCard('Part A', timeA, _errorsA, blueAccent),
          const SizedBox(height: 12),
          // Part B results
          _buildPartResultCard('Part B', timeB, _errorsB, purpleAccent),
          const SizedBox(height: 12),
          // B/A Ratio
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('B/A Ratio', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  ratio.toStringAsFixed(2),
                  style: TextStyle(
                    color: ratio < 3 ? greenAccent : (ratio < 4 ? orangeAccent : redAccent),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'B/A Ratio < 3.0 is normal. Higher ratios may indicate executive function difficulties.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildPartResultCard(String title, double timeSeconds, int errors, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${timeSeconds.toStringAsFixed(1)}s', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              Text('$errors error${errors != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}

// TMT Canvas Painter
class TMTCanvasPainter extends CustomPainter {
  final List<Offset> circlePositions;
  final List<String> circleLabels;
  final int currentTarget;
  final List<Offset> trailPath;
  final Offset? fingerPosition;
  final double circleRadius;
  final Color accentColor;
  final bool hasError;
  final List<Offset> distractorPositions;

  TMTCanvasPainter({
    required this.circlePositions,
    required this.circleLabels,
    required this.currentTarget,
    required this.trailPath,
    required this.fingerPosition,
    required this.circleRadius,
    required this.accentColor,
    required this.hasError,
    this.distractorPositions = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw trail lines
    if (trailPath.length >= 2) {
      final trailPaint = Paint()
        ..color = accentColor.withOpacity(0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(trailPath.first.dx, trailPath.first.dy);
      for (int i = 1; i < trailPath.length; i++) {
        path.lineTo(trailPath[i].dx, trailPath[i].dy);
      }
      canvas.drawPath(path, trailPaint);
    }

    // Draw line from last connected to finger
    if (trailPath.isNotEmpty && fingerPosition != null) {
      final linePaint = Paint()
        ..color = accentColor.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(trailPath.last, fingerPosition!, linePaint);
    }

    // Draw circles
    for (int i = 0; i < circlePositions.length; i++) {
      final pos = circlePositions[i];
      final isCompleted = i < currentTarget;
      final label = i < circleLabels.length ? circleLabels[i] : '';

      // Circle fill
      final fillPaint = Paint();
      if (isCompleted) {
        fillPaint.color = accentColor.withOpacity(0.2);
      } else {
        fillPaint.color = Colors.white;
      }
      canvas.drawCircle(pos, circleRadius, fillPaint);

      // Circle border — no highlight on current target so user must find it
      final borderPaint = Paint()
        ..color = isCompleted
            ? accentColor.withOpacity(0.5)
            : Colors.grey.withOpacity(0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, circleRadius, borderPaint);

      // Completed check
      if (isCompleted) {
        final checkPaint = Paint()
          ..color = accentColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final checkSize = circleRadius * 0.4;
        canvas.drawLine(
          Offset(pos.dx - checkSize * 0.5, pos.dy),
          Offset(pos.dx - checkSize * 0.1, pos.dy + checkSize * 0.4),
          checkPaint,
        );
        canvas.drawLine(
          Offset(pos.dx - checkSize * 0.1, pos.dy + checkSize * 0.4),
          Offset(pos.dx + checkSize * 0.5, pos.dy - checkSize * 0.3),
          checkPaint,
        );
      }

      // Label text — uniform style so user finds the target themselves
      if (!isCompleted) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
        );
      }
    }

    // Draw distractor circles (greyed out, not tappable)
    // These prevent spatial memorization across Part A → Part B
    for (int i = 0; i < distractorPositions.length; i++) {
      final pos = distractorPositions[i];

      // Faded circle fill
      final fillPaint = Paint()..color = Colors.grey.withOpacity(0.08);
      canvas.drawCircle(pos, circleRadius * 0.85, fillPaint);

      // Faded border
      final borderPaint = Paint()
        ..color = Colors.grey.withOpacity(0.25)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(pos, circleRadius * 0.85, borderPaint);

      // Fake label (random-looking number or letter)
      final fakeLabel = i % 2 == 0 ? '${26 + i}' : String.fromCharCode(77 + i);
      final tp = TextPainter(
        text: TextSpan(
          text: fakeLabel,
          style: TextStyle(
            color: Colors.grey.withOpacity(0.3),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
