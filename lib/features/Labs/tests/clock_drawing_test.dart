import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../../../core/responsive.dart';

enum CDTPhase { instructions, drawing, completed }

class ClockDrawingTestScreen extends StatefulWidget {
  const ClockDrawingTestScreen({super.key});

  @override
  State<ClockDrawingTestScreen> createState() => _ClockDrawingTestScreenState();
}

class _ClockDrawingTestScreenState extends State<ClockDrawingTestScreen>
    with TickerProviderStateMixin {
  CDTPhase _currentPhase = CDTPhase.instructions;

  late AnimationController _pulseController;

  // Drawing state
  List<Offset> _currentStroke = [];
  List<List<Offset>> _allStrokes = [];
  bool _isDrawing = false;
  DateTime? _drawingStartTime;
  DateTime? _drawingEndTime;

  // Canvas key for image capture
  final GlobalKey _canvasKey = GlobalKey();
  String? _capturedImageBase64;  // captured before phase transition

  // Drawing tool options
  Color _selectedColor = const Color(0xFF1A1A1A);
  double _selectedThickness = 3.0;

  static const List<Color> _penColors = [
    Color(0xFF1A1A1A), Color(0xFF3B82F6), Color(0xFFEF4444),
    Color(0xFF10B981), Color(0xFF8B5CF6), Color(0xFFF97316),
  ];
  static const List<double> _penThicknesses = [2.0, 3.0, 5.0, 7.0];

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color softLavender = Color(0xFFE8DFF0);

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

  void _startDrawing() {
    setState(() {
      _currentPhase = CDTPhase.drawing;
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

  Future<void> _finishDrawing() async {
    _drawingEndTime = DateTime.now();
    // Capture canvas image BEFORE switching phase (which removes the canvas widget)
    _capturedImageBase64 = await _captureCanvasAsBase64();
    setState(() {
      _currentPhase = CDTPhase.completed;
    });
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
        'stroke_count': 0,
      };
    }

    final duration = _drawingEndTime!.difference(_drawingStartTime!).inMilliseconds;

    // Analyze clock properties
    final center = _findCenter(allPoints);
    final circleScore = _analyzeCircle(allPoints, center);
    final numberScore = _analyzeNumberPlacement(allPoints);

    return {
      'point_count': allPoints.length,
      'stroke_count': _allStrokes.length,
      'drawing_duration_ms': duration,
      'circle_quality': circleScore,
      'number_placement_score': numberScore,
      'center_x': center.dx,
      'center_y': center.dy,
    };
  }

  Offset _findCenter(List<Offset> points) {
    double sumX = 0, sumY = 0;
    for (var p in points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    return Offset(sumX / points.length, sumY / points.length);
  }

  double _analyzeCircle(List<Offset> points, Offset center) {
    // Calculate how circular the drawing is
    List<double> distances = [];
    for (var p in points) {
      distances.add((p - center).distance);
    }
    if (distances.isEmpty) return 0;

    double mean = distances.reduce((a, b) => a + b) / distances.length;
    double variance = 0;
    for (var d in distances) {
      variance += (d - mean) * (d - mean);
    }
    variance /= distances.length;
    double stdDev = math.sqrt(variance);

    // Lower std dev relative to mean = better circle
    double cv = mean > 0 ? stdDev / mean : 1;
    return (math.max(0, 100 - cv * 200)).clamp(0, 100).toDouble();
  }

  double _analyzeNumberPlacement(List<Offset> points) {
    // Simple heuristic: more strokes = likely attempted numbers
    int strokeCount = _allStrokes.length;
    // A good clock typically has: 1 circle stroke + 12 number strokes + 2 hand strokes = ~15
    if (strokeCount >= 12) return 85;
    if (strokeCount >= 8) return 65;
    if (strokeCount >= 4) return 45;
    return 25;
  }

  Future<String?> _captureCanvasAsBase64() async {
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getTestData() async {
    final results = _calculateResults();
    // Use pre-captured image (captured before phase transition removed canvas)
    final base64Image = _capturedImageBase64 ?? await _captureCanvasAsBase64();

    return {
      'test_type': 'clock_drawing',
      'drawing_data': results,
      'image_base64': base64Image,
      'strokes': _allStrokes.map((stroke) =>
        stroke.map((p) => {'x': p.dx, 'y': p.dy}).toList()
      ).toList(),
      'completed': true,
    };
  }

  Future<void> _completeTest() async {
    HapticFeedback.mediumImpact();
    final data = await _getTestData();
    if (mounted) {
      Navigator.pop(context, data);
    }
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
                  'Clock Drawing Test',
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
      case CDTPhase.instructions:
        color = purpleAccent;
        text = 'Ready';
        icon = Icons.schedule_rounded;
        break;
      case CDTPhase.drawing:
        color = blueAccent;
        text = 'Drawing';
        icon = Icons.draw_rounded;
        break;
      case CDTPhase.completed:
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
      case CDTPhase.instructions:
        return 'Read instructions carefully';
      case CDTPhase.drawing:
        return 'Draw a clock showing 11:10';
      case CDTPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    double progress = 0;
    switch (_currentPhase) {
      case CDTPhase.instructions:
        progress = 0;
        break;
      case CDTPhase.drawing:
        progress = 0.4;
        break;
      case CDTPhase.completed:
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
      case CDTPhase.instructions:
        return _buildInstructionsPhase(r);
      case CDTPhase.drawing:
        return _buildDrawingPhase(r);
      case CDTPhase.completed:
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
              color: purpleAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time_rounded, color: purpleAccent, size: r.dp(40)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Clock Drawing Test',
            style: TextStyle(fontSize: r.sp(24), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Assess visuospatial and executive function',
            style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
          ),
          SizedBox(height: r.h(24)),
          // Clock preview
          Container(
            width: r.dp(120),
            height: r.dp(120),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(r.dp(16)),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: CustomPaint(
              painter: ClockTemplatePainter(color: Colors.grey[300]!),
            ),
          ),
          SizedBox(height: r.h(20)),
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(r.dp(14)),
            ),
            child: Column(
              children: [
                _buildInstructionRow(Icons.circle_outlined, 'Draw a large circle for the clock face', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.format_list_numbered, 'Place all 12 numbers inside the circle', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.schedule, 'Draw the hands to show 11:10', r),
                SizedBox(height: r.h(10)),
                _buildInstructionRow(Icons.timer, 'Take your time, accuracy matters', r),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _startDrawing,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: purpleAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: purpleAccent.withOpacity(0.4),
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
                  Text('Start Drawing', style: TextStyle(color: Colors.white, fontSize: r.sp(15), fontWeight: FontWeight.w700)),
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
        borderRadius: BorderRadius.circular(r.dp(14)),
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
                  borderRadius: BorderRadius.circular(r.dp(8)),
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
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: r.h(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.draw_rounded, color: blueAccent, size: r.dp(20)),
              SizedBox(width: r.w(8)),
              Text(
                'DRAW A CLOCK SHOWING 11:10',
                style: TextStyle(color: blueAccent, fontSize: r.sp(14), fontWeight: FontWeight.w700, letterSpacing: 0.5),
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
                borderRadius: BorderRadius.circular(r.dp(16)),
                border: Border.all(color: blueAccent.withOpacity(0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r.dp(14)),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: CustomPaint(
                    painter: ClockCanvasPainter(
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
          padding: EdgeInsets.all(r.dp(16)),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _clearDrawing,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.h(12)),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(r.dp(12)),
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
                      borderRadius: BorderRadius.circular(r.dp(12)),
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
                      color: _allStrokes.isNotEmpty ? blueAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(r.dp(12)),
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
    final results = _calculateResults();
    final circleQuality = (results['circle_quality'] ?? 0).toStringAsFixed(0);
    final strokeCount = results['stroke_count'] ?? 0;
    final duration = ((results['drawing_duration_ms'] ?? 0) / 1000).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.dp(20)),
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
          // Results
          Row(
            children: [
              Expanded(child: _buildResultCard('Circle Quality', '$circleQuality%', blueAccent, r)),
              SizedBox(width: r.w(12)),
              Expanded(child: _buildResultCard('Strokes', '$strokeCount', purpleAccent, r)),
            ],
          ),
          SizedBox(height: r.h(12)),
          _buildResultCard('Drawing Time', '${duration}s', darkCard, r),
          SizedBox(height: r.h(16)),
          Container(
            padding: EdgeInsets.all(r.dp(12)),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(r.dp(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: r.dp(16), color: Colors.grey),
                SizedBox(width: r.w(8)),
                Expanded(
                  child: Text(
                    'Your clock drawing will be analyzed by our AI model for visuospatial and executive function assessment.',
                    style: TextStyle(fontSize: r.sp(12), color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(color: greenAccent, borderRadius: BorderRadius.circular(r.dp(16))),
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

  Widget _buildResultCard(String label, String value, Color color, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.dp(14)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.dp(14)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: r.sp(22), fontWeight: FontWeight.w800, color: color)),
          SizedBox(height: r.h(4)),
          Text(label, style: TextStyle(fontSize: r.sp(11), color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// Clock template preview painter
class ClockTemplatePainter extends CustomPainter {
  final Color color;

  ClockTemplatePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.8;

    // Draw circle
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // Draw number positions as dots
    final dotPaint = Paint()..color = color;
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final x = cx + r * 0.75 * math.cos(angle);
      final y = cy + r * 0.75 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 2, dotPaint);
    }

    // Draw hands (11:10)
    final handPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Hour hand (pointing to ~11)
    final hourAngle = (330 - 90 + 5) * math.pi / 180;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.45 * math.cos(hourAngle), cy + r * 0.45 * math.sin(hourAngle)),
      handPaint,
    );

    // Minute hand (pointing to 2 = 10 min)
    final minAngle = (60 - 90) * math.pi / 180;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.65 * math.cos(minAngle), cy + r * 0.65 * math.sin(minAngle)),
      handPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Canvas painter for user drawing
class ClockCanvasPainter extends CustomPainter {
  final Color strokeColor;
  final double strokeWidth;
  final List<List<Offset>> allStrokes;
  final List<Offset> currentStroke;

  ClockCanvasPainter({
    required this.strokeColor,
    this.strokeWidth = 3.0,
    required this.allStrokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Light guide circle
    final guidePaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.75;
    canvas.drawCircle(Offset(cx, cy), r, guidePaint);

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = Colors.grey.withOpacity(0.2));

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
