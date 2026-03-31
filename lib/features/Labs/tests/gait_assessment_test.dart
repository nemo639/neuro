import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/responsive.dart';

// Test phases matching FOG dataset events
enum GaitFogPhase { 
  instructions,
  calibration,
  walkingOutbound,   // Walking FOG detection
  turn,              // Turn FOG detection
  walkingReturn,     // Walking FOG detection
  startStopTasks,    // Start Hesitation detection
  completed 
}

class GaitAssessmentTestScreen extends StatefulWidget {
  const GaitAssessmentTestScreen({super.key});

  @override
  State<GaitAssessmentTestScreen> createState() => _GaitAssessmentTestScreenState();
}

class _GaitAssessmentTestScreenState extends State<GaitAssessmentTestScreen>
    with TickerProviderStateMixin {
  
  GaitFogPhase _currentPhase = GaitFogPhase.instructions;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _walkController;

  // Test configuration (matching dataset protocols)
  final int _samplingRateHz = 100; // Match defog dataset
  final int _calibrationDuration = 3;
  final int _walkingDuration = 15;
  final int _turnDuration = 5;
  final int _startStopDuration = 20;
  
  int _timeRemaining = 0;
  Timer? _testTimer;
  Timer? _sensorTimer;

  // Sensor data storage (matching dataset format)
  List<double> _accV = [];   // Vertical acceleration
  List<double> _accML = [];  // Mediolateral acceleration
  List<double> _accAP = [];  // Anteroposterior acceleration
  List<int> _timestamps = [];
  
  int _sampleCount = 0;
  DateTime? _phaseStartTime;

  // Step tracking
  int _stepCount = 0;
  int _turnCount = 0;
  int _startStopCount = 0;

  // Start/Stop task tracking
  final int _totalStartStopTasks = 5;
  int _currentStartStopTask = 0;
  bool _isWalking = false;
  List<Map<String, dynamic>> _startStopEvents = [];

  // Phase results
  Map<String, dynamic> _calibrationData = {};
  Map<String, dynamic> _walkingOutboundData = {};
  Map<String, dynamic> _turnData = {};
  Map<String, dynamic> _walkingReturnData = {};
  Map<String, dynamic> _startStopData = {};

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color pinkAccent = Color(0xFFEC4899);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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
    _walkController.dispose();
    _testTimer?.cancel();
    _sensorTimer?.cancel();
    super.dispose();
  }

  // ==================== SENSOR DATA COLLECTION ====================

  void _startSensorCollection() {
    final interval = Duration(milliseconds: (1000 / _samplingRateHz).round());
    
    _sensorTimer = Timer.periodic(interval, (timer) {
      _collectSensorSample();
    });
  }

  void _stopSensorCollection() {
    _sensorTimer?.cancel();
  }

  void _collectSensorSample() {
    // Simulated sensor data - real app would use accelerometer package
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Simulate realistic accelerometer values (in g units, matching defog dataset)
    double accV, accML, accAP;
    
    switch (_currentPhase) {
      case GaitFogPhase.calibration:
        // Standing still - minimal movement
        accV = 1.0 + (random.nextDouble() - 0.5) * 0.05;
        accML = (random.nextDouble() - 0.5) * 0.05;
        accAP = (random.nextDouble() - 0.5) * 0.05;
        break;
        
      case GaitFogPhase.walkingOutbound:
      case GaitFogPhase.walkingReturn:
        // Walking pattern - rhythmic vertical oscillation
        final walkPhase = (_sampleCount % 50) / 50.0 * 2 * math.pi;
        accV = 1.0 + math.sin(walkPhase) * 0.3 + (random.nextDouble() - 0.5) * 0.1;
        accML = math.sin(walkPhase * 2) * 0.15 + (random.nextDouble() - 0.5) * 0.05;
        accAP = math.cos(walkPhase) * 0.2 + (random.nextDouble() - 0.5) * 0.05;
        
        // Simulate step detection
        if (_sampleCount % 50 == 25) {
          setState(() => _stepCount++);
          HapticFeedback.selectionClick();
        }
        break;
        
      case GaitFogPhase.turn:
        // Turning - more lateral movement
        accV = 1.0 + (random.nextDouble() - 0.5) * 0.2;
        accML = math.sin(_sampleCount * 0.1) * 0.4 + (random.nextDouble() - 0.5) * 0.1;
        accAP = math.cos(_sampleCount * 0.1) * 0.3 + (random.nextDouble() - 0.5) * 0.1;
        break;
        
      case GaitFogPhase.startStopTasks:
        // Variable - depends on walking/stopping state
        if (_isWalking) {
          final walkPhase = (_sampleCount % 50) / 50.0 * 2 * math.pi;
          accV = 1.0 + math.sin(walkPhase) * 0.3 + (random.nextDouble() - 0.5) * 0.1;
          accML = math.sin(walkPhase * 2) * 0.15 + (random.nextDouble() - 0.5) * 0.05;
          accAP = math.cos(walkPhase) * 0.2 + (random.nextDouble() - 0.5) * 0.05;
        } else {
          accV = 1.0 + (random.nextDouble() - 0.5) * 0.05;
          accML = (random.nextDouble() - 0.5) * 0.05;
          accAP = (random.nextDouble() - 0.5) * 0.05;
        }
        break;
        
      default:
        accV = 1.0;
        accML = 0.0;
        accAP = 0.0;
    }
    
    setState(() {
      _accV.add(accV);
      _accML.add(accML);
      _accAP.add(accAP);
      _timestamps.add(timestamp);
      _sampleCount++;
    });
  }

  Map<String, dynamic> _extractPhaseData() {
    return {
      'sample_count': _sampleCount,
      'duration_ms': _phaseStartTime != null 
          ? DateTime.now().difference(_phaseStartTime!).inMilliseconds 
          : 0,
      'acc_v': List<double>.from(_accV),
      'acc_ml': List<double>.from(_accML),
      'acc_ap': List<double>.from(_accAP),
      'timestamps': List<int>.from(_timestamps),
    };
  }

  void _resetPhaseData() {
    _accV.clear();
    _accML.clear();
    _accAP.clear();
    _timestamps.clear();
    _sampleCount = 0;
    _phaseStartTime = DateTime.now();
  }

  // ==================== PHASE TRANSITIONS ====================

  void _startCalibration() {
    setState(() {
      _currentPhase = GaitFogPhase.calibration;
      _timeRemaining = _calibrationDuration;
    });
    _resetPhaseData();
    _startSensorCollection();
    
    _testTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _stopSensorCollection();
        _calibrationData = _extractPhaseData();
        _startWalkingOutbound();
      }
    });
  }

  void _startWalkingOutbound() {
    setState(() {
      _currentPhase = GaitFogPhase.walkingOutbound;
      _timeRemaining = _walkingDuration;
      _stepCount = 0;
    });
    _resetPhaseData();
    _startSensorCollection();
    
    _testTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _stopSensorCollection();
        _walkingOutboundData = {
          ..._extractPhaseData(),
          'step_count': _stepCount,
          'event_type': 'Walking',
        };
        _startTurn();
      }
    });
  }

  void _startTurn() {
    setState(() {
      _currentPhase = GaitFogPhase.turn;
      _timeRemaining = _turnDuration;
      _turnCount = 0;
    });
    _resetPhaseData();
    _startSensorCollection();
    
    _testTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _stopSensorCollection();
        _turnData = {
          ..._extractPhaseData(),
          'event_type': 'Turn',
        };
        _startWalkingReturn();
      }
    });
  }

  void _startWalkingReturn() {
    setState(() {
      _currentPhase = GaitFogPhase.walkingReturn;
      _timeRemaining = _walkingDuration;
      _stepCount = 0;
    });
    _resetPhaseData();
    _startSensorCollection();
    
    _testTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _stopSensorCollection();
        _walkingReturnData = {
          ..._extractPhaseData(),
          'step_count': _stepCount,
          'event_type': 'Walking',
        };
        _startStartStopTasks();
      }
    });
  }

  void _startStartStopTasks() {
    setState(() {
      _currentPhase = GaitFogPhase.startStopTasks;
      _timeRemaining = _startStopDuration;
      _currentStartStopTask = 0;
      _isWalking = false;
      _startStopEvents = [];
      _startStopCount = 0;
    });
    _resetPhaseData();
    _startSensorCollection();
    
    _testTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _timeRemaining--);
      
      if (_timeRemaining <= 0) {
        timer.cancel();
        _stopSensorCollection();
        _startStopData = {
          ..._extractPhaseData(),
          'events': _startStopEvents,
          'total_start_stops': _startStopCount,
          'event_type': 'StartHesitation',
        };
        _completeTest();
      }
    });
  }

  void _toggleStartStop() {
    HapticFeedback.mediumImpact();
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    setState(() {
      _isWalking = !_isWalking;
      _startStopCount++;
      
      _startStopEvents.add({
        'timestamp': timestamp,
        'action': _isWalking ? 'start' : 'stop',
        'task_number': _currentStartStopTask,
      });
      
      if (!_isWalking) {
        _currentStartStopTask++;
      }
    });
  }

  void _completeTest() {
    setState(() {
      _currentPhase = GaitFogPhase.completed;
    });
  }

  // ==================== TEST DATA ====================

  Map<String, dynamic> _getTestData() {
    // Combine all phase data
    final allAccV = [
      ..._calibrationData['acc_v'] ?? [],
      ..._walkingOutboundData['acc_v'] ?? [],
      ..._turnData['acc_v'] ?? [],
      ..._walkingReturnData['acc_v'] ?? [],
      ..._startStopData['acc_v'] ?? [],
    ];
    
    final allAccML = [
      ..._calibrationData['acc_ml'] ?? [],
      ..._walkingOutboundData['acc_ml'] ?? [],
      ..._turnData['acc_ml'] ?? [],
      ..._walkingReturnData['acc_ml'] ?? [],
      ..._startStopData['acc_ml'] ?? [],
    ];
    
    final allAccAP = [
      ..._calibrationData['acc_ap'] ?? [],
      ..._walkingOutboundData['acc_ap'] ?? [],
      ..._turnData['acc_ap'] ?? [],
      ..._walkingReturnData['acc_ap'] ?? [],
      ..._startStopData['acc_ap'] ?? [],
    ];

    return {
      'test_type': 'gait_fog_assessment',
      'sampling_rate_hz': _samplingRateHz,
      'total_samples': allAccV.length,
      'total_duration_ms': (allAccV.length / _samplingRateHz * 1000).round(),
      
      // Combined sensor data (matching dataset format)
      'sensor_data': {
        'acc_v': allAccV,
        'acc_ml': allAccML,
        'acc_ap': allAccAP,
      },
      
      // Phase-specific data
      'phases': {
        'calibration': _calibrationData,
        'walking_outbound': _walkingOutboundData,
        'turn': _turnData,
        'walking_return': _walkingReturnData,
        'start_stop_tasks': _startStopData,
      },
      
      // Summary metrics
      'summary': {
        'total_steps': (_walkingOutboundData['step_count'] ?? 0) + 
                       (_walkingReturnData['step_count'] ?? 0),
        'start_stop_count': _startStopCount,
        'walking_duration_s': _walkingDuration * 2,
        'turn_duration_s': _turnDuration,
      },
      
      'completed': true,
    };
  }

  void _finishTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _testTimer?.cancel();
    _sensorTimer?.cancel();
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

  // ==================== BUILD METHODS ====================

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
            if (_currentPhase != GaitFogPhase.instructions && 
                _currentPhase != GaitFogPhase.completed)
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
              child: Icon(Icons.arrow_back_ios_new_rounded, size: r.dp(18)),
            ),
          ),
          SizedBox(width: r.w(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gait Assessment',
                  style: TextStyle(fontSize: r.sp(20), fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildPhaseIndicator(r),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator(Responsive r) {
    Color color;
    String text;
    IconData icon;

    switch (_currentPhase) {
      case GaitFogPhase.instructions:
        color = tealAccent;
        text = 'Ready';
        icon = Icons.directions_walk_rounded;
        break;
      case GaitFogPhase.calibration:
        color = orangeAccent;
        text = 'Calibrating';
        icon = Icons.sensors_rounded;
        break;
      case GaitFogPhase.walkingOutbound:
        color = blueAccent;
        text = 'Walking →';
        icon = Icons.arrow_forward_rounded;
        break;
      case GaitFogPhase.turn:
        color = purpleAccent;
        text = 'Turn';
        icon = Icons.rotate_right_rounded;
        break;
      case GaitFogPhase.walkingReturn:
        color = indigoAccent;
        text = '← Return';
        icon = Icons.arrow_back_rounded;
        break;
      case GaitFogPhase.startStopTasks:
        color = pinkAccent;
        text = 'Start/Stop';
        icon = Icons.play_arrow_rounded;
        break;
      case GaitFogPhase.completed:
        color = greenAccent;
        text = 'Done';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(6)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.dp(20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: r.dp(14)),
          SizedBox(width: r.w(4)),
          Text(text, style: TextStyle(color: color, fontSize: r.sp(11), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case GaitFogPhase.instructions:
        return 'FOG-provoking protocol';
      case GaitFogPhase.calibration:
        return 'Stand still for calibration';
      case GaitFogPhase.walkingOutbound:
        return 'Walk forward at normal pace';
      case GaitFogPhase.turn:
        return 'Turn around 180°';
      case GaitFogPhase.walkingReturn:
        return 'Walk back to start';
      case GaitFogPhase.startStopTasks:
        return 'Start and stop on command';
      case GaitFogPhase.completed:
        return 'Assessment complete';
    }
  }

  Widget _buildProgressBar(Responsive r) {
    final totalDuration = _calibrationDuration + (_walkingDuration * 2) + _turnDuration + _startStopDuration;
    double progress = 0;

    switch (_currentPhase) {
      case GaitFogPhase.instructions:
        progress = 0;
        break;
      case GaitFogPhase.calibration:
        progress = (1 - _timeRemaining / _calibrationDuration) * (_calibrationDuration / totalDuration);
        break;
      case GaitFogPhase.walkingOutbound:
        progress = (_calibrationDuration / totalDuration) +
            (1 - _timeRemaining / _walkingDuration) * (_walkingDuration / totalDuration);
        break;
      case GaitFogPhase.turn:
        progress = ((_calibrationDuration + _walkingDuration) / totalDuration) +
            (1 - _timeRemaining / _turnDuration) * (_turnDuration / totalDuration);
        break;
      case GaitFogPhase.walkingReturn:
        progress = ((_calibrationDuration + _walkingDuration + _turnDuration) / totalDuration) +
            (1 - _timeRemaining / _walkingDuration) * (_walkingDuration / totalDuration);
        break;
      case GaitFogPhase.startStopTasks:
        progress = ((_calibrationDuration + _walkingDuration * 2 + _turnDuration) / totalDuration) +
            (1 - _timeRemaining / _startStopDuration) * (_startStopDuration / totalDuration);
        break;
      case GaitFogPhase.completed:
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
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [tealAccent, blueAccent, purpleAccent, pinkAccent],
            ),
            borderRadius: BorderRadius.circular(r.dp(3)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Responsive r) {
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
      case GaitFogPhase.instructions:
        return _buildInstructionsPhase(r);
      case GaitFogPhase.calibration:
        return _buildCalibrationPhase(r);
      case GaitFogPhase.walkingOutbound:
      case GaitFogPhase.walkingReturn:
        return _buildWalkingPhase(r);
      case GaitFogPhase.turn:
        return _buildTurnPhase(r);
      case GaitFogPhase.startStopTasks:
        return _buildStartStopPhase(r);
      case GaitFogPhase.completed:
        return _buildCompletedPhase(r);
    }
  }

  Widget _buildInstructionsPhase(Responsive r) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: r.h(10)),
          Container(
            width: r.w(80),
            height: r.h(80),
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_walk_rounded, color: tealAccent, size: r.dp(40)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Gait Assessment',
            style: TextStyle(fontSize: r.sp(24), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(8)),
          Text(
            'Freezing of Gait (FOG) Protocol',
            style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
          ),
          SizedBox(height: r.h(20)),
          // Protocol phases
          Container(
            padding: EdgeInsets.all(r.dp(14)),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(r.dp(14)),
            ),
            child: Column(
              children: [
                _buildPhasePreview(r, Icons.arrow_forward_rounded, 'Walk Forward', '15 sec', blueAccent),
                SizedBox(height: r.h(10)),
                _buildPhasePreview(r, Icons.rotate_right_rounded, 'Turn Around', '5 sec', purpleAccent),
                SizedBox(height: r.h(10)),
                _buildPhasePreview(r, Icons.arrow_back_rounded, 'Walk Back', '15 sec', indigoAccent),
                SizedBox(height: r.h(10)),
                _buildPhasePreview(r, Icons.play_arrow_rounded, 'Start/Stop Tasks', '20 sec', pinkAccent),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          // Safety warning
          Container(
            padding: EdgeInsets.all(r.dp(12)),
            decoration: BoxDecoration(
              color: orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: orangeAccent, size: r.dp(20)),
                SizedBox(width: r.w(10)),
                Expanded(
                  child: Text(
                    'Stay near a wall or support. Clear path of 10m needed.',
                    style: TextStyle(fontSize: r.sp(12), color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(12)),
          // Phone position
          Container(
            padding: EdgeInsets.all(r.dp(12)),
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(r.dp(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.phone_android_rounded, color: blueAccent, size: r.dp(20)),
                SizedBox(width: r.w(10)),
                Expanded(
                  child: Text(
                    'Secure phone at lower back (belt/pocket)',
                    style: TextStyle(fontSize: r.sp(12), color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _startCalibration,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: tealAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
                boxShadow: [
                  BoxShadow(
                    color: tealAccent.withOpacity(0.4),
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
                    'Start Assessment',
                    style: TextStyle(color: Colors.white, fontSize: r.sp(15), fontWeight: FontWeight.w700),
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

  Widget _buildPhasePreview(Responsive r, IconData icon, String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: r.w(36),
          height: r.h(36),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(r.dp(10)),
          ),
          child: Icon(icon, color: color, size: r.dp(18)),
        ),
        SizedBox(width: r.w(12)),
        Expanded(
          child: Text(title, style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600)),
        ),
        Text(duration, style: TextStyle(fontSize: r.sp(12), color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildCalibrationPhase(Responsive r) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: r.w(120) + (_pulseController.value * 20),
              height: r.h(120) + (_pulseController.value * 20),
              decoration: BoxDecoration(
                color: orangeAccent.withOpacity(0.1 + _pulseController.value * 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: r.w(80),
                  height: r.h(80),
                  decoration: const BoxDecoration(
                    color: orangeAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_timeRemaining',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.sp(36),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: r.h(30)),
        Text(
          'Stand Still',
          style: TextStyle(fontSize: r.sp(24), fontWeight: FontWeight.w700),
        ),
        SizedBox(height: r.h(8)),
        Text(
          'Calibrating sensors...',
          style: TextStyle(fontSize: r.sp(14), color: Colors.grey[600]),
        ),
        SizedBox(height: r.h(20)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(8)),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(r.dp(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_rounded, color: orangeAccent, size: r.dp(18)),
              SizedBox(width: r.w(8)),
              Text(
                '$_sampleCount samples',
                style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalkingPhase(Responsive r) {
    final isOutbound = _currentPhase == GaitFogPhase.walkingOutbound;
    final color = isOutbound ? blueAccent : indigoAccent;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(10)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.dp(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOutbound ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                color: color,
                size: r.dp(20),
              ),
              SizedBox(width: r.w(8)),
              Text(
                isOutbound ? 'WALK FORWARD' : 'WALK BACK',
                style: TextStyle(
                  color: color,
                  fontSize: r.sp(16),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.h(30)),
        Text(
          '$_timeRemaining',
          style: TextStyle(
            fontSize: r.sp(64),
            fontWeight: FontWeight.w300,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: r.h(20)),
        // Walking animation
        AnimatedBuilder(
          animation: _walkController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(math.sin(_walkController.value * 2 * math.pi) * 15, 0),
              child: Icon(
                Icons.directions_walk_rounded,
                size: r.dp(60),
                color: color,
              ),
            );
          },
        ),
        SizedBox(height: r.h(20)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(24), vertical: r.h(12)),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.dp(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_walk, color: Colors.black54, size: r.dp(24)),
              SizedBox(width: r.w(10)),
              Text(
                '$_stepCount steps',
                style: TextStyle(
                  fontSize: r.sp(18),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.h(16)),
        Text(
          'Walk at your normal pace',
          style: TextStyle(fontSize: r.sp(14), color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTurnPhase(Responsive r) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(10)),
          decoration: BoxDecoration(
            color: purpleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.dp(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rotate_right_rounded, color: purpleAccent, size: r.dp(20)),
              SizedBox(width: r.w(8)),
              Text(
                'TURN AROUND',
                style: TextStyle(
                  color: purpleAccent,
                  fontSize: r.sp(16),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.h(30)),
        Text(
          '$_timeRemaining',
          style: TextStyle(
            fontSize: r.sp(64),
            fontWeight: FontWeight.w300,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: r.h(20)),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _pulseController.value * math.pi,
              child: Container(
                width: r.w(100),
                height: r.h(100),
                decoration: BoxDecoration(
                  color: purpleAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rotate_right_rounded,
                  size: r.dp(60),
                  color: purpleAccent,
                ),
              ),
            );
          },
        ),
        SizedBox(height: r.h(20)),
        Text(
          'Turn 180° carefully',
          style: TextStyle(fontSize: r.sp(14), color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStartStopPhase(Responsive r) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(10)),
          decoration: BoxDecoration(
            color: pinkAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(r.dp(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isWalking ? Icons.directions_walk_rounded : Icons.accessibility_new_rounded,
                color: pinkAccent,
                size: r.dp(20),
              ),
              SizedBox(width: r.w(8)),
              Text(
                _isWalking ? 'WALKING' : 'STOPPED',
                style: TextStyle(
                  color: pinkAccent,
                  fontSize: r.sp(16),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.h(20)),
        Text(
          '$_timeRemaining',
          style: TextStyle(
            fontSize: r.sp(48),
            fontWeight: FontWeight.w300,
            color: Colors.black54,
          ),
        ),
        SizedBox(height: r.h(20)),
        // Big tap button
        GestureDetector(
          onTap: _toggleStartStop,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: r.w(140) + (_pulseController.value * 10),
                height: r.h(140) + (_pulseController.value * 10),
                decoration: BoxDecoration(
                  color: _isWalking 
                      ? redAccent.withOpacity(0.1) 
                      : greenAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: r.w(100),
                    height: r.h(100),
                    decoration: BoxDecoration(
                      color: _isWalking ? redAccent : greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isWalking ? redAccent : greenAccent).withOpacity(0.4),
                          blurRadius: r.dp(20),
                          spreadRadius: r.dp(5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isWalking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: r.dp(36),
                        ),
                        Text(
                          _isWalking ? 'STOP' : 'START',
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
              );
            },
          ),
        ),
        SizedBox(height: r.h(20)),
        Text(
          _isWalking 
              ? 'Walk until you tap STOP' 
              : 'Tap START and begin walking',
          style: TextStyle(fontSize: r.sp(14), color: Colors.grey[600]),
        ),
        SizedBox(height: r.h(16)),
        // Progress indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalStartStopTasks, (index) {
            final isCompleted = index < _currentStartStopTask;
            final isCurrent = index == _currentStartStopTask;
            return Container(
              margin: EdgeInsets.symmetric(horizontal: r.w(4)),
              width: isCurrent ? 12 : 8,
              height: isCurrent ? 12 : 8,
              decoration: BoxDecoration(
                color: isCompleted 
                    ? greenAccent 
                    : (isCurrent ? pinkAccent : Colors.grey[300]),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
        SizedBox(height: r.h(8)),
        Text(
          'Task ${_currentStartStopTask + 1} of $_totalStartStopTasks',
          style: TextStyle(fontSize: r.sp(12), color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildCompletedPhase(Responsive r) {
    final data = _getTestData();
    final summary = data['summary'] as Map<String, dynamic>;

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: r.h(10)),
          Container(
            width: r.w(80),
            height: r.h(80),
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded, color: greenAccent, size: r.dp(45)),
          ),
          SizedBox(height: r.h(20)),
          Text(
            'Assessment Complete!',
            style: TextStyle(fontSize: r.sp(22), fontWeight: FontWeight.w800),
          ),
          SizedBox(height: r.h(8)),
          Text(
            '${data['total_samples']} sensor samples collected',
            style: TextStyle(fontSize: r.sp(13), color: Colors.grey[600]),
          ),
          SizedBox(height: r.h(20)),
          // Results summary
          Container(
            padding: EdgeInsets.all(r.dp(16)),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(r.dp(16)),
            ),
            child: Column(
              children: [
                _buildResultRow(r, 'Total Steps', '${summary['total_steps']}'),
                Divider(height: r.h(20)),
                _buildResultRow(r, 'Walking Duration', '${summary['walking_duration_s']}s'),
                Divider(height: r.h(20)),
                _buildResultRow(r, 'Start/Stop Tasks', '${summary['start_stop_count']}'),
              ],
            ),
          ),
          SizedBox(height: r.h(16)),
          // Phase breakdown
          Row(
            children: [
              Expanded(child: _buildPhaseCard(r, 'Walking', blueAccent, Icons.directions_walk_rounded)),
              SizedBox(width: r.w(8)),
              Expanded(child: _buildPhaseCard(r, 'Turn', purpleAccent, Icons.rotate_right_rounded)),
              SizedBox(width: r.w(8)),
              Expanded(child: _buildPhaseCard(r, 'Start/Stop', pinkAccent, Icons.play_arrow_rounded)),
            ],
          ),
          SizedBox(height: r.h(16)),
          Container(
            padding: EdgeInsets.all(r.dp(12)),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(r.dp(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey, size: r.dp(18)),
                SizedBox(width: r.w(10)),
                Expanded(
                  child: Text(
                    'Data will be analyzed for FOG patterns',
                    style: TextStyle(fontSize: r.sp(12), color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.h(24)),
          GestureDetector(
            onTap: _finishTest,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(14)),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(r.dp(16)),
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
          SizedBox(height: r.h(10)),
        ],
      ),
    );
  }

  Widget _buildResultRow(Responsive r, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: r.sp(14), color: Colors.grey[700])),
        Text(value, style: TextStyle(fontSize: r.sp(16), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildPhaseCard(Responsive r, String title, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(r.dp(12)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(r.dp(12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: r.dp(24)),
          SizedBox(height: r.h(6)),
          Text(
            title,
            style: TextStyle(fontSize: r.sp(11), color: color, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: r.h(2)),
          Icon(Icons.check_circle, color: greenAccent, size: r.dp(16)),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(Responsive r) {
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
          _buildMiniMetric(r, 'SAMPLES', '$_sampleCount', tealAccent),
          Container(width: r.w(1), height: r.h(36), color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric(r, 'TIME', '${_timeRemaining}s', blueAccent),
          Container(width: r.w(1), height: r.h(36), color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric(r, 'STEPS', '$_stepCount', orangeAccent),
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
          ),
        ),
        SizedBox(height: r.h(4)),
        Row(
          children: [
            Container(
              width: r.w(8),
              height: r.h(8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
}