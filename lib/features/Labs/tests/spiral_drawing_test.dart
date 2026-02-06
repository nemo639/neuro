import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Test phases
enum SpiralPhase { instructions, leftHand, rightHand, completed }

class SpiralDrawingTestScreen extends StatefulWidget {
  const SpiralDrawingTestScreen({super.key});

  @override
  State<SpiralDrawingTestScreen> createState() => _SpiralDrawingTestScreenState();
}

class _SpiralDrawingTestScreenState extends State<SpiralDrawingTestScreen>
    with TickerProviderStateMixin {
  
  SpiralPhase _currentPhase = SpiralPhase.instructions;

  // Animation controllers
  late AnimationController _pulseController;

  // Drawing state
  List<Offset> _currentStroke = [];
  List<List<Offset>> _allStrokes = [];
  bool _isDrawing = false;
  DateTime? _drawingStartTime;
  DateTime? _drawingEndTime;

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
    super.dispose();
  }

  void _startLeftHand() {
    setState(() {
      _currentPhase = SpiralPhase.leftHand;
      _currentStroke = [];
      _allStrokes = [];
      _drawingStartTime = null;
      _drawingEndTime = null;
    });
  }

  void _startRightHand() {
    setState(() {
      _currentPhase = SpiralPhase.rightHand;
      _currentStroke = [];
      _allStrokes = [];
      _drawingStartTime = null;
      _drawingEndTime = null;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDrawing = true;
      _drawingStartTime ??= DateTime.now();
      _currentStroke = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDrawing) return;
    setState(() {
      _currentStroke.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDrawing = false;
      if (_currentStroke.isNotEmpty) {
        _allStrokes.add(List.from(_currentStroke));
      }
      _currentStroke = [];
    });
  }

  void _clearDrawing() {
    setState(() {
      _currentStroke = [];
      _allStrokes = [];
      _drawingStartTime = null;
    });
  }

  void _finishDrawing() {
    _drawingEndTime = DateTime.now();
    final results = _calculateResults();

    if (_currentPhase == SpiralPhase.leftHand) {
      _leftHandResults = results;
      Future.delayed(const Duration(milliseconds: 500), _startRightHand);
    } else {
      _rightHandResults = results;
      setState(() {
        _currentPhase = SpiralPhase.completed;
      });
    }
  }

  Map<String, dynamic> _calculateResults() {
    List<Offset> allPoints = [];
    for (var stroke in _allStrokes) {
      allPoints.addAll(stroke);
    }

    if (allPoints.length < 2) {
      return {
        'point_count': 0,
        'drawing_duration_ms': 0,
        'tremor_score': 0,
        'accuracy_score': 0,
      };
    }

    final duration = _drawingEndTime!.difference(_drawingStartTime!).inMilliseconds;

    // Calculate tremor (deviation from smooth line)
    double totalDeviation = 0;
    for (int i = 1; i < allPoints.length - 1; i++) {
      final prev = allPoints[i - 1];
      final curr = allPoints[i];
      final next = allPoints[i + 1];
      
      final expectedX = (prev.dx + next.dx) / 2;
      final expectedY = (prev.dy + next.dy) / 2;
      
      final deviation = math.sqrt(
        math.pow(curr.dx - expectedX, 2) + math.pow(curr.dy - expectedY, 2)
      );
      totalDeviation += deviation;
    }
    final avgDeviation = totalDeviation / (allPoints.length - 2);
    final tremorScore = math.max(0, 100 - avgDeviation * 5).clamp(0, 100);

    // Calculate accuracy
    double totalDistance = 0;
    for (var point in allPoints) {
      final distance = _distanceToSpiral(point, 150, 150, 20);
      totalDistance += distance;
    }
    final avgDistance = totalDistance / allPoints.length;
    final accuracyScore = math.max(0, 100 - avgDistance * 2).clamp(0, 100);

    return {
      'point_count': allPoints.length,
      'stroke_count': _allStrokes.length,
      'drawing_duration_ms': duration,
      'tremor_score': tremorScore.toDouble(),
      'accuracy_score': accuracyScore.toDouble(),
      'avg_deviation': avgDeviation,
    };
  }

  double _distanceToSpiral(Offset point, double centerX, double centerY, double spacing) {
    double minDistance = double.infinity;
    
    for (double t = 0; t <= 3 * 2 * math.pi; t += 0.1) {
      final r = spacing * t / (2 * math.pi);
      final spiralX = centerX + r * math.cos(t);
      final spiralY = centerY + r * math.sin(t);
      
      final distance = math.sqrt(
        math.pow(point.dx - spiralX, 2) + math.pow(point.dy - spiralY, 2)
      );
      
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    
    return minDistance;
  }

  Map<String, dynamic> _getTestData() {
    return {
      'test_type': 'spiral_drawing',
      'left_hand': _leftHandResults,
      'right_hand': _rightHandResults,
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
                  'Spiral Drawing',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildHandIndicator(),
        ],
      ),
    );
  }

  Widget _buildHandIndicator() {
    Color color;
    String text;
    IconData icon;

    switch (_currentPhase) {
      case SpiralPhase.instructions:
        color = orangeAccent;
        text = 'Ready';
        icon = Icons.gesture_rounded;
        break;
      case SpiralPhase.leftHand:
        color = blueAccent;
        text = 'Left';
        icon = Icons.back_hand_rounded;
        break;
      case SpiralPhase.rightHand:
        color = purpleAccent;
        text = 'Right';
        icon = Icons.front_hand_rounded;
        break;
      case SpiralPhase.completed:
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
      case SpiralPhase.instructions:
        return 'Read instructions carefully';
      case SpiralPhase.leftHand:
        return 'Trace with your left hand';
      case SpiralPhase.rightHand:
        return 'Trace with your right hand';
      case SpiralPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar() {
    double progress = 0;
    switch (_currentPhase) {
      case SpiralPhase.instructions:
        progress = 0;
        break;
      case SpiralPhase.leftHand:
        progress = 0.25;
        break;
      case SpiralPhase.rightHand:
        progress = 0.6;
        break;
      case SpiralPhase.completed:
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
            gradient: const LinearGradient(colors: [blueAccent, purpleAccent]),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case SpiralPhase.instructions:
        return _buildInstructionsPhase();
      case SpiralPhase.leftHand:
      case SpiralPhase.rightHand:
        return _buildDrawingPhase();
      case SpiralPhase.completed:
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
            decoration: BoxDecoration(
              color: orangeAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gesture_rounded, color: orangeAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Spiral Drawing Test',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Assess hand tremor and coordination',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          // Mini spiral preview
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: CustomPaint(
              painter: SpiralTemplatePainter(color: Colors.grey[300]!),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.gesture, 'Trace the spiral from center outward'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.speed, 'Draw at a comfortable speed'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.back_hand, 'Left hand first, then right hand'),
                const SizedBox(height: 10),
                _buildInstructionRow(Icons.straighten, 'Try to stay on the line'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startLeftHand,
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
                  Text('Start Test', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _buildDrawingPhase() {
    final isLeft = _currentPhase == SpiralPhase.leftHand;
    final color = isLeft ? blueAccent : purpleAccent;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isLeft ? Icons.back_hand_rounded : Icons.front_hand_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                isLeft ? 'LEFT HAND' : 'RIGHT HAND',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CustomPaint(
                  painter: SpiralCanvasPainter(
                    templateColor: Colors.grey[300]!,
                    strokeColor: color,
                    allStrokes: _allStrokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _clearDrawing,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 6),
                        Text('Clear', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _allStrokes.isNotEmpty ? _finishDrawing : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _allStrokes.isNotEmpty ? color : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedPhase() {
    final leftTremor = (_leftHandResults['tremor_score'] ?? 0).toStringAsFixed(0);
    final rightTremor = (_rightHandResults['tremor_score'] ?? 0).toStringAsFixed(0);
    final leftAccuracy = (_leftHandResults['accuracy_score'] ?? 0).toStringAsFixed(0);
    final rightAccuracy = (_rightHandResults['accuracy_score'] ?? 0).toStringAsFixed(0);

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
          Row(
            children: [
              Expanded(child: _buildHandResultCard('Left Hand', leftTremor, leftAccuracy, blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildHandResultCard('Right Hand', rightTremor, rightAccuracy, purpleAccent)),
            ],
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
                    const Icon(Icons.vibration, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Tremor Score: Higher = less tremor', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.track_changes, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Accuracy: How close to the template', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  Widget _buildHandResultCard(String title, String tremor, String accuracy, Color color) {
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(tremor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                  Text('Tremor', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
              Column(
                children: [
                  Text(accuracy, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                  Text('Accuracy', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Spiral template painter
class SpiralTemplatePainter extends CustomPainter {
  final Color color;

  SpiralTemplatePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final spacing = size.width / 8;

    bool first = true;
    for (double t = 0; t <= 3 * 2 * math.pi; t += 0.1) {
      final r = spacing * t / (2 * math.pi);
      final x = centerX + r * math.cos(t);
      final y = centerY + r * math.sin(t);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Drawing canvas painter
class SpiralCanvasPainter extends CustomPainter {
  final Color templateColor;
  final Color strokeColor;
  final List<List<Offset>> allStrokes;
  final List<Offset> currentStroke;

  SpiralCanvasPainter({
    required this.templateColor,
    required this.strokeColor,
    required this.allStrokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw spiral template
    final templatePaint = Paint()
      ..color = templateColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final templatePath = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final spacing = size.width / 8;

    bool first = true;
    for (double t = 0; t <= 3 * 2 * math.pi; t += 0.1) {
      final r = spacing * t / (2 * math.pi);
      final x = centerX + r * math.cos(t);
      final y = centerY + r * math.sin(t);

      if (first) {
        templatePath.moveTo(x, y);
        first = false;
      } else {
        templatePath.lineTo(x, y);
      }
    }
    canvas.drawPath(templatePath, templatePaint);

    // Draw user strokes
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var stroke in allStrokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }

    // Draw current stroke
    if (currentStroke.length >= 2) {
      final path = Path();
      path.moveTo(currentStroke.first.dx, currentStroke.first.dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}