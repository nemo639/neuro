import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(child: _buildContent()),
            if (_currentPhase != GaitFogPhase.instructions && 
                _currentPhase != GaitFogPhase.completed)
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
                  'Gait Assessment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildPhaseIndicator(),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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

  Widget _buildProgressBar() {
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
            gradient: const LinearGradient(
              colors: [tealAccent, blueAccent, purpleAccent, pinkAccent],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
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
      case GaitFogPhase.instructions:
        return _buildInstructionsPhase();
      case GaitFogPhase.calibration:
        return _buildCalibrationPhase();
      case GaitFogPhase.walkingOutbound:
      case GaitFogPhase.walkingReturn:
        return _buildWalkingPhase();
      case GaitFogPhase.turn:
        return _buildTurnPhase();
      case GaitFogPhase.startStopTasks:
        return _buildStartStopPhase();
      case GaitFogPhase.completed:
        return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_walk_rounded, color: tealAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Gait Assessment',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Freezing of Gait (FOG) Protocol',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          // Protocol phases
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildPhasePreview(Icons.arrow_forward_rounded, 'Walk Forward', '15 sec', blueAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.rotate_right_rounded, 'Turn Around', '5 sec', purpleAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.arrow_back_rounded, 'Walk Back', '15 sec', indigoAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.play_arrow_rounded, 'Start/Stop Tasks', '20 sec', pinkAccent),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Safety warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: orangeAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stay near a wall or support. Clear path of 10m needed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Phone position
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_android_rounded, color: blueAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Secure phone at lower back (belt/pocket)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startCalibration,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: tealAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: tealAccent.withOpacity(0.4),
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
                    'Start Assessment',
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

  Widget _buildPhasePreview(IconData icon, String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Text(duration, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildCalibrationPhase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 120 + (_pulseController.value * 20),
              height: 120 + (_pulseController.value * 20),
              decoration: BoxDecoration(
                color: orangeAccent.withOpacity(0.1 + _pulseController.value * 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: orangeAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_timeRemaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        const Text(
          'Stand Still',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Calibrating sensors...',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors_rounded, color: orangeAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                '$_sampleCount samples',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalkingPhase() {
    final isOutbound = _currentPhase == GaitFogPhase.walkingOutbound;
    final color = isOutbound ? blueAccent : indigoAccent;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOutbound ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isOutbound ? 'WALK FORWARD' : 'WALK BACK',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          '$_timeRemaining',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        // Walking animation
        AnimatedBuilder(
          animation: _walkController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(math.sin(_walkController.value * 2 * math.pi) * 15, 0),
              child: Icon(
                Icons.directions_walk_rounded,
                size: 60,
                color: color,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_walk, color: Colors.black54, size: 24),
              const SizedBox(width: 10),
              Text(
                '$_stepCount steps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Walk at your normal pace',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTurnPhase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: purpleAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rotate_right_rounded, color: purpleAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'TURN AROUND',
                style: TextStyle(
                  color: purpleAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Text(
          '$_timeRemaining',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _pulseController.value * math.pi,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: purpleAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rotate_right_rounded,
                  size: 60,
                  color: purpleAccent,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Turn 180° carefully',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStartStopPhase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: pinkAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isWalking ? Icons.directions_walk_rounded : Icons.accessibility_new_rounded,
                color: pinkAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isWalking ? 'WALKING' : 'STOPPED',
                style: const TextStyle(
                  color: pinkAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '$_timeRemaining',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w300,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        // Big tap button
        GestureDetector(
          onTap: _toggleStartStop,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 140 + (_pulseController.value * 10),
                height: 140 + (_pulseController.value * 10),
                decoration: BoxDecoration(
                  color: _isWalking 
                      ? redAccent.withOpacity(0.1) 
                      : greenAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: _isWalking ? redAccent : greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isWalking ? redAccent : greenAccent).withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isWalking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        Text(
                          _isWalking ? 'STOP' : 'START',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
        const SizedBox(height: 20),
        Text(
          _isWalking 
              ? 'Walk until you tap STOP' 
              : 'Tap START and begin walking',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        // Progress indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalStartStopTasks, (index) {
            final isCompleted = index < _currentStartStopTask;
            final isCurrent = index == _currentStartStopTask;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
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
        const SizedBox(height: 8),
        Text(
          'Task ${_currentStartStopTask + 1} of $_totalStartStopTasks',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildCompletedPhase() {
    final data = _getTestData();
    final summary = data['summary'] as Map<String, dynamic>;

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
            'Assessment Complete!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${data['total_samples']} sensor samples collected',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          // Results summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildResultRow('Total Steps', '${summary['total_steps']}'),
                const Divider(height: 20),
                _buildResultRow('Walking Duration', '${summary['walking_duration_s']}s'),
                const Divider(height: 20),
                _buildResultRow('Start/Stop Tasks', '${summary['start_stop_count']}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Phase breakdown
          Row(
            children: [
              Expanded(child: _buildPhaseCard('Walking', blueAccent, Icons.directions_walk_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildPhaseCard('Turn', purpleAccent, Icons.rotate_right_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildPhaseCard('Start/Stop', pinkAccent, Icons.play_arrow_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data will be analyzed for FOG patterns',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _finishTest,
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

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildPhaseCard(String title, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          const Icon(Icons.check_circle, color: greenAccent, size: 16),
        ],
      ),
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
          _buildMiniMetric('SAMPLES', '$_sampleCount', tealAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('TIME', '${_timeRemaining}s', blueAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('STEPS', '$_stepCount', orangeAccent),
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
}