import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/responsive.dart';

enum MeanderPhase { instructions, leftHand, rightHand, completed }

class MeanderDrawingTestScreen extends StatefulWidget {
  const MeanderDrawingTestScreen({super.key});

  @override
  State<MeanderDrawingTestScreen> createState() => _MeanderDrawingTestScreenState();
}

class _MeanderDrawingTestScreenState extends State<MeanderDrawingTestScreen>
    with TickerProviderStateMixin {
  MeanderPhase _currentPhase = MeanderPhase.instructions;

  late AnimationController _pulseController;

  // Drawing state
  List<Offset> _currentStroke = [];
  List<List<Offset>> _allStrokes = [];
  bool _isDrawing = false;
  DateTime? _drawingStartTime;
  DateTime? _drawingEndTime;

  // Canvas key for image capture
  final GlobalKey _canvasKey = GlobalKey();

  // Drawing tool options
  Color _selectedColor = const Color(0xFF3B82F6);
  double _selectedThickness = 4.0;

  static const List<Color> _penColors = [
    Color(0xFF1A1A1A), Color(0xFF3B82F6), Color(0xFFEF4444),
    Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF97316),
  ];
  static const List<double> _penThicknesses = [2.0, 4.0, 6.0, 8.0];

  // Results
  Map<String, dynamic> _leftHandResults = {};
  Map<String, dynamic> _rightHandResults = {};

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color tealAccent = Color(0xFF14B8A6);

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
      _currentPhase = MeanderPhase.leftHand;
      _currentStroke = [];
      _allStrokes = [];
      _drawingStartTime = null;
      _drawingEndTime = null;
    });
  }

  void _startRightHand() {
    setState(() {
      _currentPhase = MeanderPhase.rightHand;
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

  Future<String?> _captureCanvasImage() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Canvas capture failed: $e');
      return null;
    }
  }

  Future<void> _finishDrawing() async {
    _drawingEndTime = DateTime.now();
    final results = _calculateResults();

    // Capture drawing as base64 image for the ML model
    final imageBase64 = await _captureCanvasImage();
    if (imageBase64 != null) {
      results['image_base64'] = imageBase64;
    }

    if (_currentPhase == MeanderPhase.leftHand) {
      _leftHandResults = results;
      Future.delayed(const Duration(milliseconds: 500), _startRightHand);
    } else {
      _rightHandResults = results;
      setState(() {
        _currentPhase = MeanderPhase.completed;
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
        'smoothness_score': 0,
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
        math.pow(curr.dx - expectedX, 2) + math.pow(curr.dy - expectedY, 2),
      );
      totalDeviation += deviation;
    }
    final avgDeviation = totalDeviation / (allPoints.length - 2);
    final tremorScore = math.max(0, 100 - avgDeviation * 5).clamp(0, 100);

    // Smoothness: angle changes between consecutive segments
    double totalAngleChange = 0;
    int angleCount = 0;
    for (int i = 2; i < allPoints.length; i++) {
      final v1 = allPoints[i - 1] - allPoints[i - 2];
      final v2 = allPoints[i] - allPoints[i - 1];
      if (v1.distance > 0.5 && v2.distance > 0.5) {
        final dot = v1.dx * v2.dx + v1.dy * v2.dy;
        final cross = v1.dx * v2.dy - v1.dy * v2.dx;
        final angle = math.atan2(cross, dot).abs();
        totalAngleChange += angle;
        angleCount++;
      }
    }
    final avgAngle = angleCount > 0 ? totalAngleChange / angleCount : 0;
    final smoothnessScore = math.max(0, 100 - avgAngle * 100).clamp(0, 100);

    // Speed calculation
    final durationSec = duration / 1000.0;
    double totalDist = 0;
    for (int i = 1; i < allPoints.length; i++) {
      totalDist += (allPoints[i] - allPoints[i - 1]).distance;
    }
    final meanSpeed = durationSec > 0 ? totalDist / durationSec : 0;

    return {
      'point_count': allPoints.length,
      'stroke_count': _allStrokes.length,
      'drawing_duration_ms': duration,
      'tremor_score': tremorScore.toDouble(),
      'smoothness_score': smoothnessScore.toDouble(),
      'avg_deviation': avgDeviation,
      'mean_speed': meanSpeed,
    };
  }

  Map<String, dynamic> _getTestData() {
    return {
      'test_type': 'meander_drawing',
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
                borderRadius: BorderRadius.circular(r.w(14)),
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
                  'Meander Drawing',
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
      case MeanderPhase.instructions:
        color = tealAccent;
        text = 'Ready';
        icon = Icons.gesture_rounded;
        break;
      case MeanderPhase.leftHand:
        color = blueAccent;
        text = 'Left';
        icon = Icons.back_hand_rounded;
        break;
      case MeanderPhase.rightHand:
        color = purpleAccent;
        text = 'Right';
        icon = Icons.front_hand_rounded;
        break;
      case MeanderPhase.completed:
        color = greenAccent;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(6)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.w(20)),
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
      case MeanderPhase.instructions:
        return 'Read instructions carefully';
      case MeanderPhase.leftHand:
        return 'Trace with your left hand';
      case MeanderPhase.rightHand:
        return 'Trace with your right hand';
      case MeanderPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    double progress = 0;
    switch (_currentPhase) {
      case MeanderPhase.instructions:
        progress = 0;
        break;
      case MeanderPhase.leftHand:
        progress = 0.25;
        break;
      case MeanderPhase.rightHand:
        progress = 0.6;
        break;
      case MeanderPhase.completed:
        progress = 1.0;
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.w(20)),
      height: r.h(6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(r.w(3)),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [tealAccent, blueAccent]),
            borderRadius: BorderRadius.circular(r.w(3)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Responsive r) {
    return Container(
      margin: EdgeInsets.all(r.w(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.w(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.w(24)),
        child: _buildPhaseContent(r),
      ),
    );
  }

  Widget _buildPhaseContent(Responsive r) {
    switch (_currentPhase) {
      case MeanderPhase.instructions:
        return _buildInstructionsPhase(r);
      case MeanderPhase.leftHand:
      case MeanderPhase.rightHand:
        return _buildDrawingPhase(r);
      case MeanderPhase.completed:
        return _buildCompletedPhase(r);
    }
  }

  Widget _buildInstructionsPhase(Responsive r) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.w(20)),
      child: Column(
        children: [
          SizedBox(height: r.h(10)),
          Container(
            width: r.dp(80),
            height: r.dp(80),
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.show_chart_rounded, color: tealAccent, size: r.dp(40)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Meander Drawing Test',
            style: TextStyle(fontSize: r.sp(24), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Assess tremor and motor smoothness',
            style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
          ),
          SizedBox(height: r.h(24)),
          // Meander preview
          Container(
            width: r.w(200),
            height: r.h(80),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(r.w(16)),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: CustomPaint(
              painter: MeanderTemplatePainter(color: Colors.grey[300]!),
            ),
          ),
          SizedBox(height: r.h(20)),
          Container(
            padding: EdgeInsets.all(r.w(14)),
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(r.w(14)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.show_chart, 'Trace the zigzag pattern carefully', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.speed, 'Draw at a comfortable speed', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.back_hand, 'Left hand first, then right hand', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.straighten, 'Try to stay on the line', r),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _startLeftHand,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: tealAccent,
                borderRadius: BorderRadius.circular(r.w(16)),
                boxShadow: [
                  BoxShadow(
                    color: tealAccent.withOpacity(0.4),
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

  Widget _buildDrawingToolbar(Responsive r) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.w(20)),
      padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.w(14)),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _penColors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: r.dp(22), height: r.dp(22),
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(
                      color: _selectedColor == c ? Colors.black87 : Colors.transparent, width: 2.5,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
          Container(width: r.w(1), height: r.h(24), color: Colors.grey[300], margin: EdgeInsets.symmetric(horizontal: r.w(4))),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _penThicknesses.map((t) => GestureDetector(
              onTap: () => setState(() => _selectedThickness = t),
              child: Container(
                width: r.dp(26), height: r.dp(26),
                margin: EdgeInsets.symmetric(horizontal: r.w(1)),
                decoration: BoxDecoration(
                  color: _selectedThickness == t ? Colors.grey[200] : Colors.transparent,
                  borderRadius: BorderRadius.circular(r.w(8)),
                ),
                child: Center(child: Container(
                  width: t + 2, height: t + 2,
                  decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle),
                )),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingPhase(Responsive r) {
    final isLeft = _currentPhase == MeanderPhase.leftHand;
    final phaseColor = isLeft ? blueAccent : purpleAccent;

    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(6)),
          padding: EdgeInsets.symmetric(vertical: r.h(10), horizontal: r.w(16)),
          decoration: BoxDecoration(
            color: phaseColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.w(12)),
            border: Border.all(color: phaseColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isLeft ? Icons.back_hand_rounded : Icons.front_hand_rounded, color: phaseColor, size: r.dp(22)),
              SizedBox(width: r.w(10)),
              Column(
                children: [
                  Text(
                    isLeft ? 'LEFT HAND' : 'RIGHT HAND',
                    style: TextStyle(color: phaseColor, fontSize: r.sp(16), fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  SizedBox(height: r.h(2)),
                  Text(
                    isLeft ? 'Use only your left hand to draw' : 'Use only your right hand to draw',
                    style: TextStyle(color: phaseColor.withOpacity(0.7), fontSize: r.sp(11)),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDrawingToolbar(r),
        SizedBox(height: r.h(8)),
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: r.w(20)),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(r.w(16)),
                border: Border.all(color: phaseColor.withOpacity(0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r.w(14)),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: CustomPaint(
                    painter: MeanderCanvasPainter(
                      templateColor: Colors.grey[300]!,
                      strokeColor: _selectedColor,
                      strokeWidth: _selectedThickness,
                      allStrokes: _allStrokes,
                      currentStroke: _currentStroke,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(r.w(16)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _clearDrawing,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.h(12)),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(r.w(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.grey[600], size: r.dp(20)),
                        SizedBox(width: r.w(6)),
                        Text('Clear', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                child: GestureDetector(
                  onTap: _allStrokes.isNotEmpty ? () {
                    setState(() => _allStrokes.removeLast());
                  } : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.h(12)),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(r.w(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.undo_rounded, color: _allStrokes.isNotEmpty ? Colors.grey[600] : Colors.grey[400], size: r.dp(20)),
                        SizedBox(width: r.w(6)),
                        Text('Undo', style: TextStyle(color: _allStrokes.isNotEmpty ? Colors.grey[600] : Colors.grey[400], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.w(8)),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _allStrokes.isNotEmpty ? _finishDrawing : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.h(12)),
                    decoration: BoxDecoration(
                      color: _allStrokes.isNotEmpty ? phaseColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(r.w(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: r.dp(20)),
                        SizedBox(width: r.w(6)),
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

  Widget _buildCompletedPhase(Responsive r) {
    final leftTremor = (_leftHandResults['tremor_score'] ?? 0).toStringAsFixed(0);
    final rightTremor = (_rightHandResults['tremor_score'] ?? 0).toStringAsFixed(0);
    final leftSmooth = (_leftHandResults['smoothness_score'] ?? 0).toStringAsFixed(0);
    final rightSmooth = (_rightHandResults['smoothness_score'] ?? 0).toStringAsFixed(0);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.w(20)),
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
          Text('Test Completed!', style: TextStyle(fontSize: r.sp(22), fontWeight: FontWeight.w800)),
          SizedBox(height: r.h(20)),
          Row(
            children: [
              Expanded(child: _buildHandResultCard('Left Hand', leftTremor, leftSmooth, blueAccent, r)),
              SizedBox(width: r.w(12)),
              Expanded(child: _buildHandResultCard('Right Hand', rightTremor, rightSmooth, purpleAccent, r)),
            ],
          ),
          SizedBox(height: r.h(16)),
          Container(
            padding: EdgeInsets.all(r.w(12)),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(r.w(12)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.vibration, size: r.dp(16), color: Colors.grey),
                    SizedBox(width: r.w(8)),
                    Text('Tremor Score: Higher = less tremor', style: TextStyle(fontSize: r.sp(12), color: Colors.grey[600])),
                  ],
                ),
                SizedBox(height: r.h(6)),
                Row(
                  children: [
                    Icon(Icons.waves, size: r.dp(16), color: Colors.grey),
                    SizedBox(width: r.w(8)),
                    Text('Smoothness: How fluid the drawing is', style: TextStyle(fontSize: r.sp(12), color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(color: greenAccent, borderRadius: BorderRadius.circular(r.w(16))),
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

  Widget _buildHandResultCard(String title, String tremor, String smoothness, Color color, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.w(14)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.w(14)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: r.sp(12), color: color, fontWeight: FontWeight.w600)),
          SizedBox(height: r.h(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(tremor, style: TextStyle(fontSize: r.sp(22), fontWeight: FontWeight.w800, color: color)),
                  Text('Tremor', style: TextStyle(fontSize: r.sp(10), color: Colors.grey[600])),
                ],
              ),
              Column(
                children: [
                  Text(smoothness, style: TextStyle(fontSize: r.sp(22), fontWeight: FontWeight.w800, color: color)),
                  Text('Smooth', style: TextStyle(fontSize: r.sp(10), color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Meander template painter (zigzag pattern)
class MeanderTemplatePainter extends CustomPainter {
  final Color color;

  MeanderTemplatePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final margin = 15.0;
    final amplitude = (h - margin * 2) / 2;
    final centerY = h / 2;
    final segments = 6;
    final segWidth = (w - margin * 2) / segments;

    path.moveTo(margin, centerY);

    for (int i = 0; i < segments; i++) {
      final x1 = margin + i * segWidth;
      final x2 = margin + (i + 1) * segWidth;
      final goUp = i % 2 == 0;

      path.lineTo(x1 + segWidth * 0.1, goUp ? centerY - amplitude : centerY + amplitude);
      path.lineTo(x2 - segWidth * 0.1, goUp ? centerY - amplitude : centerY + amplitude);
      path.lineTo(x2, centerY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Canvas painter for meander drawing
class MeanderCanvasPainter extends CustomPainter {
  final Color templateColor;
  final Color strokeColor;
  final double strokeWidth;
  final List<List<Offset>> allStrokes;
  final List<Offset> currentStroke;

  MeanderCanvasPainter({
    required this.templateColor,
    required this.strokeColor,
    this.strokeWidth = 4.0,
    required this.allStrokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw meander template
    final templatePaint = Paint()
      ..color = templateColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final templatePath = Path();
    final w = size.width;
    final h = size.height;
    final margin = 30.0;
    final amplitude = (h - margin * 2) * 0.35;
    final centerY = h / 2;
    final segments = 8;
    final segWidth = (w - margin * 2) / segments;

    templatePath.moveTo(margin, centerY);

    for (int i = 0; i < segments; i++) {
      final x1 = margin + i * segWidth;
      final x2 = margin + (i + 1) * segWidth;
      final goUp = i % 2 == 0;

      templatePath.lineTo(x1 + segWidth * 0.1, goUp ? centerY - amplitude : centerY + amplitude);
      templatePath.lineTo(x2 - segWidth * 0.1, goUp ? centerY - amplitude : centerY + amplitude);
      templatePath.lineTo(x2, centerY);
    }

    canvas.drawPath(templatePath, templatePaint);

    // Draw user strokes
    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
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
