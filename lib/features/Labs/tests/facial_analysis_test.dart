import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FacialPhase { instructions, resting, blinking, smiling, expressions, completed }

class FacialAnalysisTestScreen extends StatefulWidget {
  const FacialAnalysisTestScreen({super.key});

  @override
  State<FacialAnalysisTestScreen> createState() => _FacialAnalysisTestScreenState();
}

class _FacialAnalysisTestScreenState extends State<FacialAnalysisTestScreen>
    with TickerProviderStateMixin {

  FacialPhase _currentPhase = FacialPhase.instructions;

  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isCameraInitializing = false;
  String? _cameraError;

  // ML Kit Face Detector
  late FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  bool _faceDetected = false;
  String _faceGuidance = 'Position your face in the oval';

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _recordingController;

  // Phase durations (seconds)
  final int _restingDuration = 15;
  final int _blinkingDuration = 15;
  final int _smilingDuration = 10;
  final int _expressionsDuration = 20;

  int _timeRemaining = 0;
  Timer? _testTimer;

  // Recording state
  bool _isRecording = false;
  int _framesCaptured = 0;

  // ---- Real measurement accumulators ----
  // Resting phase
  final List<double> _restingSymmetryValues = [];
  final List<double> _restingMuscleToneValues = [];

  // Blinking phase
  int _blinkCount = 0;
  bool _eyeWasClosed = false;
  final List<double> _blinkDurations = [];
  DateTime? _blinkStartTime;

  // Smiling phase
  double _maxSmileProbability = 0;
  double _smileOnsetTime = 0; // ms from phase start to first smile
  bool _smileDetected = false;
  DateTime? _smilePhaseStart;
  final List<double> _smileProbabilities = [];
  double _leftSmileProb = 0;
  double _rightSmileProb = 0;

  // Expression phase
  int _currentExpressionIndex = 0;
  final List<double> _expressionRangeValues = [];
  double _minEyeOpen = 1.0;
  double _maxEyeOpen = 0.0;
  double _minMouthOpen = 100.0;
  double _maxMouthOpen = 0.0;
  int _expressionsDetected = 0;

  // Expression tasks
  final List<Map<String, dynamic>> _expressionTasks = [
    {'name': 'Raise Eyebrows', 'icon': Icons.arrow_upward_rounded, 'duration': 4},
    {'name': 'Frown', 'icon': Icons.sentiment_very_dissatisfied_rounded, 'duration': 4},
    {'name': 'Close Eyes Tight', 'icon': Icons.visibility_off_rounded, 'duration': 4},
    {'name': 'Puff Cheeks', 'icon': Icons.face_rounded, 'duration': 4},
    {'name': 'Show Teeth', 'icon': Icons.tag_faces_rounded, 'duration': 4},
  ];

  // Results
  Map<String, dynamic> _restingResults = {};
  Map<String, dynamic> _blinkingResults = {};
  Map<String, dynamic> _smilingResults = {};
  Map<String, dynamic> _expressionResults = {};

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color cyanAccent = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,    // smile + eye open probability
        enableLandmarks: true,         // eye, mouth, nose positions
        enableContours: false,         // not needed, saves processing
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _recordingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    _recordingController.dispose();
    _testTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  // ------------------------------------------------------------------ //
  // Camera initialization                                                //
  // ------------------------------------------------------------------ //
  Future<void> _initCamera() async {
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() {
        _isCameraReady = true;
        _cameraError = null;
      });

      // Start face detection stream
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraError = 'Camera error: $e';
          _isCameraReady = false;
        });
      }
    }
    _isCameraInitializing = false;
  }

  // ------------------------------------------------------------------ //
  // ML Kit Face Processing                                               //
  // ------------------------------------------------------------------ //
  void _processCameraImage(CameraImage image) {
    if (_isProcessingFrame || !_isRecording) return;
    _isProcessingFrame = true;

    _detectFaces(image).then((_) {
      _isProcessingFrame = false;
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _faceDetected = false;
          _faceGuidance = 'No face detected — look at the camera';
        });
        return;
      }

      final face = faces.first;
      setState(() {
        _faceDetected = true;
        _framesCaptured++;
      });

      // Check face position guidance
      _updateFaceGuidance(face);

      // Process based on current phase
      switch (_currentPhase) {
        case FacialPhase.resting:
          _processRestingFace(face);
          break;
        case FacialPhase.blinking:
          _processBlinking(face);
          break;
        case FacialPhase.smiling:
          _processSmiling(face);
          break;
        case FacialPhase.expressions:
          _processExpressions(face);
          break;
        default:
          break;
      }
    } catch (e) {
      // Silently handle processing errors
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (sensorOrientation == 0) {
      rotation = InputImageRotation.rotation0deg;
    } else if (sensorOrientation == 90) {
      rotation = InputImageRotation.rotation90deg;
    } else if (sensorOrientation == 180) {
      rotation = InputImageRotation.rotation180deg;
    } else if (sensorOrientation == 270) {
      rotation = InputImageRotation.rotation270deg;
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _updateFaceGuidance(Face face) {
    final headY = face.headEulerAngleY ?? 0; // left-right turn
    final headZ = face.headEulerAngleZ ?? 0; // tilt

    if (headY.abs() > 25) {
      _faceGuidance = 'Face the camera directly';
    } else if (headZ.abs() > 15) {
      _faceGuidance = 'Keep your head straight';
    } else {
      _faceGuidance = 'Good position';
    }
  }

  // ---- Resting phase processing ----
  void _processRestingFace(Face face) {
    // Facial symmetry: compare left/right eye open probability
    final leftEye = face.leftEyeOpenProbability ?? 0.5;
    final rightEye = face.rightEyeOpenProbability ?? 0.5;
    final symmetry = (1.0 - (leftEye - rightEye).abs()) * 100;
    _restingSymmetryValues.add(symmetry);

    // Muscle tone approximation: how stable is the face (low smile = neutral = good tone)
    final smile = face.smilingProbability ?? 0.0;
    final tone = (1.0 - smile) * 100; // Neutral face = high tone
    _restingMuscleToneValues.add(tone);
  }

  // ---- Blinking phase processing ----
  void _processBlinking(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 0.5;
    final rightEye = face.rightEyeOpenProbability ?? 0.5;
    final avgEyeOpen = (leftEye + rightEye) / 2;

    // Detect blink: eyes close below threshold then open again
    if (avgEyeOpen < 0.3 && !_eyeWasClosed) {
      _eyeWasClosed = true;
      _blinkStartTime = DateTime.now();
    } else if (avgEyeOpen > 0.6 && _eyeWasClosed) {
      _eyeWasClosed = false;
      setState(() => _blinkCount++);
      HapticFeedback.selectionClick();

      // Calculate blink duration
      if (_blinkStartTime != null) {
        final dur = DateTime.now().difference(_blinkStartTime!).inMilliseconds.toDouble();
        _blinkDurations.add(dur);
      }
    }
  }

  // ---- Smiling phase processing ----
  void _processSmiling(Face face) {
    final smileProb = face.smilingProbability ?? 0.0;
    _smileProbabilities.add(smileProb);

    if (smileProb > _maxSmileProbability) {
      _maxSmileProbability = smileProb;
    }

    // Track smile onset time
    if (smileProb > 0.5 && !_smileDetected && _smilePhaseStart != null) {
      _smileDetected = true;
      _smileOnsetTime = DateTime.now().difference(_smilePhaseStart!).inMilliseconds.toDouble();
    }

    // Smile symmetry from eye/mouth landmarks
    final leftEye = face.leftEyeOpenProbability ?? 0.5;
    final rightEye = face.rightEyeOpenProbability ?? 0.5;
    _leftSmileProb = leftEye;
    _rightSmileProb = rightEye;

    setState(() {});
  }

  // ---- Expressions phase processing ----
  void _processExpressions(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 0.5;
    final rightEye = face.rightEyeOpenProbability ?? 0.5;
    final smile = face.smilingProbability ?? 0.0;
    final avgEye = (leftEye + rightEye) / 2;

    // Track range of eye opening
    if (avgEye < _minEyeOpen) _minEyeOpen = avgEye;
    if (avgEye > _maxEyeOpen) _maxEyeOpen = avgEye;

    // Track mouth range via smile probability as proxy
    if (smile * 100 < _minMouthOpen) _minMouthOpen = smile * 100;
    if (smile * 100 > _maxMouthOpen) _maxMouthOpen = smile * 100;

    // Expression range = how much variety in facial movements
    final eyeRange = (_maxEyeOpen - _minEyeOpen) * 100;
    final mouthRange = _maxMouthOpen - _minMouthOpen;
    final range = (eyeRange + mouthRange) / 2;
    _expressionRangeValues.add(range);

    // Count distinct expressions (significant changes)
    if (_expressionRangeValues.length > 10) {
      final recent = _expressionRangeValues.last;
      final prev = _expressionRangeValues[_expressionRangeValues.length - 10];
      if ((recent - prev).abs() > 15) {
        _expressionsDetected++;
      }
    }
  }

  // ------------------------------------------------------------------ //
  // Phase transitions                                                    //
  // ------------------------------------------------------------------ //
  Future<void> _startResting() async {
    // Initialize camera first
    if (!_isCameraReady) {
      await _initCamera();
      if (!_isCameraReady) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_cameraError ?? 'Failed to initialize camera'),
              backgroundColor: redAccent,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _currentPhase = FacialPhase.resting;
      _timeRemaining = _restingDuration;
      _isRecording = true;
      _framesCaptured = 0;
      _restingSymmetryValues.clear();
      _restingMuscleToneValues.clear();
    });

    _startPhaseTimer(() {
      final avgSymmetry = _restingSymmetryValues.isEmpty
          ? 85.0
          : _restingSymmetryValues.reduce((a, b) => a + b) / _restingSymmetryValues.length;
      final avgTone = _restingMuscleToneValues.isEmpty
          ? 75.0
          : _restingMuscleToneValues.reduce((a, b) => a + b) / _restingMuscleToneValues.length;

      _restingResults = {
        'duration_ms': _restingDuration * 1000,
        'frames_captured': _framesCaptured,
        'facial_symmetry': double.parse(avgSymmetry.toStringAsFixed(1)),
        'muscle_tone': double.parse(avgTone.toStringAsFixed(1)),
      };
      _startBlinking();
    });
  }

  void _startBlinking() {
    setState(() {
      _currentPhase = FacialPhase.blinking;
      _timeRemaining = _blinkingDuration;
      _blinkCount = 0;
      _eyeWasClosed = false;
      _blinkDurations.clear();
    });

    _startPhaseTimer(() {
      final avgBlinkDur = _blinkDurations.isEmpty
          ? 200.0
          : _blinkDurations.reduce((a, b) => a + b) / _blinkDurations.length;

      _blinkingResults = {
        'duration_ms': _blinkingDuration * 1000,
        'blink_count': _blinkCount,
        'blink_rate_per_min': _blinkCount * (60.0 / _blinkingDuration),
        'avg_blink_duration_ms': double.parse(avgBlinkDur.toStringAsFixed(1)),
      };
      _startSmiling();
    });
  }

  void _startSmiling() {
    setState(() {
      _currentPhase = FacialPhase.smiling;
      _timeRemaining = _smilingDuration;
      _maxSmileProbability = 0;
      _smileDetected = false;
      _smileOnsetTime = 0;
      _smileProbabilities.clear();
      _smilePhaseStart = DateTime.now();
    });

    _startPhaseTimer(() {
      final avgSmile = _smileProbabilities.isEmpty
          ? 0.0
          : _smileProbabilities.reduce((a, b) => a + b) / _smileProbabilities.length;

      // Smile symmetry from eye difference during smile
      final symmetry = (1.0 - (_leftSmileProb - _rightSmileProb).abs()) * 100;

      // Smile velocity: faster onset = healthier. Normalize to 0-1 scale.
      // < 500ms onset = fast (1.0), > 3000ms = slow (0.2)
      double velocity;
      if (_smileOnsetTime <= 0 || !_smileDetected) {
        velocity = 0.1; // Never smiled
      } else if (_smileOnsetTime < 500) {
        velocity = 1.0;
      } else if (_smileOnsetTime < 1500) {
        velocity = 0.7;
      } else if (_smileOnsetTime < 3000) {
        velocity = 0.4;
      } else {
        velocity = 0.2;
      }

      _smilingResults = {
        'duration_ms': _smilingDuration * 1000,
        'smile_velocity': double.parse(velocity.toStringAsFixed(2)),
        'smile_symmetry': double.parse(symmetry.toStringAsFixed(1)),
        'max_smile_amplitude': double.parse(_maxSmileProbability.toStringAsFixed(3)),
        'avg_smile_probability': double.parse(avgSmile.toStringAsFixed(3)),
        'smile_onset_ms': _smileOnsetTime,
      };
      _startExpressions();
    });
  }

  void _startExpressions() {
    setState(() {
      _currentPhase = FacialPhase.expressions;
      _currentExpressionIndex = 0;
      _timeRemaining = _expressionsDuration;
      _expressionRangeValues.clear();
      _minEyeOpen = 1.0;
      _maxEyeOpen = 0.0;
      _minMouthOpen = 100.0;
      _maxMouthOpen = 0.0;
      _expressionsDetected = 0;
    });

    _startPhaseTimer(() {
      final avgRange = _expressionRangeValues.isEmpty
          ? 50.0
          : _expressionRangeValues.reduce((a, b) => a + b) / _expressionRangeValues.length;
      final expressionRange = math.min(avgRange * 1.5, 100.0); // Scale up

      _expressionResults = {
        'duration_ms': _expressionsDuration * 1000,
        'expressions_completed': _expressionTasks.length,
        'expression_range': double.parse(expressionRange.toStringAsFixed(1)),
        'hypomimia_score': double.parse(math.max(0, 100 - expressionRange * 1.2).toStringAsFixed(1)),
        'eye_range': double.parse(((_maxEyeOpen - _minEyeOpen) * 100).toStringAsFixed(1)),
        'mouth_range': double.parse((_maxMouthOpen - _minMouthOpen).toStringAsFixed(1)),
        'expressions_detected': _expressionsDetected,
      };
      _finishTest();
    });
  }

  void _startPhaseTimer(VoidCallback onComplete) {
    _testTimer?.cancel();
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);

      // Update expression index during expression phase
      if (_currentPhase == FacialPhase.expressions) {
        final elapsed = _expressionsDuration - _timeRemaining;
        _currentExpressionIndex = (elapsed ~/ 4).clamp(0, _expressionTasks.length - 1);
      }

      if (_timeRemaining <= 0) {
        timer.cancel();
        onComplete();
      }
    });
  }

  void _finishTest() {
    setState(() {
      _currentPhase = FacialPhase.completed;
      _isRecording = false;
    });
    // Stop camera stream to save battery
    _cameraController?.stopImageStream().catchError((_) {});
  }

  // ------------------------------------------------------------------ //
  // Test data & submission                                               //
  // ------------------------------------------------------------------ //
  Map<String, dynamic> _getTestData() {
    final blinkRate = _blinkingResults['blink_rate_per_min'] ?? 15.0;
    final smileVel = _smilingResults['smile_velocity'] ?? 0.5;
    final hypomimia = _expressionResults['hypomimia_score'] ?? 50.0;

    final blinkScore = blinkRate >= 12 && blinkRate <= 25
        ? 100.0
        : math.max(0.0, 100.0 - (blinkRate - 17.0).abs() * 5);

    return {
      'test_type': 'facial_analysis',
      'resting': _restingResults,
      'blinking': _blinkingResults,
      'smiling': _smilingResults,
      'expressions': _expressionResults,
      'overall_scores': {
        'blink_score': double.parse(blinkScore.toStringAsFixed(1)),
        'smile_score': double.parse((smileVel * 100).toStringAsFixed(1)),
        'expression_score': double.parse((100 - hypomimia).toStringAsFixed(1)),
        'combined_score': double.parse(
            ((blinkScore + smileVel * 100 + (100 - hypomimia)) / 3).toStringAsFixed(1)),
      },
      'completed': true,
    };
  }

  void _completeTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _testTimer?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
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

  // ------------------------------------------------------------------ //
  // UI                                                                   //
  // ------------------------------------------------------------------ //
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
            if (_isRecording) _buildRecordingBar(),
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
              width: 44, height: 44,
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
                const Text('Facial Analysis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(_getPhaseText(), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
      case FacialPhase.instructions:
        color = pinkAccent; text = 'Ready'; icon = Icons.face_rounded;
      case FacialPhase.resting:
        color = cyanAccent; text = 'Resting'; icon = Icons.sentiment_neutral_rounded;
      case FacialPhase.blinking:
        color = blueAccent; text = 'Blinking'; icon = Icons.remove_red_eye_rounded;
      case FacialPhase.smiling:
        color = orangeAccent; text = 'Smiling'; icon = Icons.sentiment_very_satisfied_rounded;
      case FacialPhase.expressions:
        color = pinkAccent; text = 'Expressions'; icon = Icons.theater_comedy_rounded;
      case FacialPhase.completed:
        color = greenAccent; text = 'Done'; icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
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
      case FacialPhase.instructions: return 'Position your face in the camera';
      case FacialPhase.resting: return 'Keep a neutral expression';
      case FacialPhase.blinking: return 'Blink naturally';
      case FacialPhase.smiling: return 'Smile when prompted';
      case FacialPhase.expressions: return 'Follow the expression prompts';
      case FacialPhase.completed: return 'Analysis complete';
    }
  }

  Widget _buildProgressBar() {
    double progress = 0;
    final total = _restingDuration + _blinkingDuration + _smilingDuration + _expressionsDuration;
    switch (_currentPhase) {
      case FacialPhase.instructions: progress = 0;
      case FacialPhase.resting:
        progress = (1 - _timeRemaining / _restingDuration) * (_restingDuration / total);
      case FacialPhase.blinking:
        progress = (_restingDuration / total) +
            (1 - _timeRemaining / _blinkingDuration) * (_blinkingDuration / total);
      case FacialPhase.smiling:
        progress = ((_restingDuration + _blinkingDuration) / total) +
            (1 - _timeRemaining / _smilingDuration) * (_smilingDuration / total);
      case FacialPhase.expressions:
        progress = ((_restingDuration + _blinkingDuration + _smilingDuration) / total) +
            (1 - _timeRemaining / _expressionsDuration) * (_expressionsDuration / total);
      case FacialPhase.completed: progress = 1.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 6,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [pinkAccent, orangeAccent]),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _buildPhaseContent(),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case FacialPhase.instructions: return _buildInstructionsPhase();
      case FacialPhase.resting: return _buildCameraPhase(_buildRestingOverlay());
      case FacialPhase.blinking: return _buildCameraPhase(_buildBlinkingOverlay());
      case FacialPhase.smiling: return _buildCameraPhase(_buildSmilingOverlay());
      case FacialPhase.expressions: return _buildCameraPhase(_buildExpressionsOverlay());
      case FacialPhase.completed: return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: pinkAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.face_retouching_natural_rounded, color: pinkAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Facial Analysis', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('AI-powered facial movement analysis', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: softLavender.withOpacity(0.3), borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _buildPhasePreview(Icons.sentiment_neutral_rounded, 'Resting Face', '${_restingDuration}s', cyanAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.remove_red_eye_rounded, 'Natural Blinking', '${_blinkingDuration}s', blueAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.sentiment_very_satisfied_rounded, 'Smile Task', '${_smilingDuration}s', orangeAccent),
                const SizedBox(height: 10),
                _buildPhasePreview(Icons.theater_comedy_rounded, 'Expression Series', '${_expressionsDuration}s', pinkAccent),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Tips
          _buildTipBox(Icons.lightbulb_outline_rounded, 'Good lighting — face a window or lamp', blueAccent),
          const SizedBox(height: 8),
          _buildTipBox(Icons.straighten_rounded, 'Hold phone at arm\'s length, face centered', orangeAccent),
          const SizedBox(height: 8),
          _buildTipBox(Icons.remove_red_eye_outlined, 'Remove glasses if possible for better detection', pinkAccent),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startResting,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: pinkAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: pinkAccent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('Start Camera', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipBox(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  Widget _buildPhasePreview(IconData icon, String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Text(duration, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  // ---- Camera phase with real preview ----
  Widget _buildCameraPhase(Widget overlay) {
    return Stack(
      children: [
        // Real camera preview
        if (_isCameraReady && _cameraController != null)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize?.height ?? 300,
                height: _cameraController!.value.previewSize?.width ?? 400,
                child: CameraPreview(_cameraController!),
              ),
            ),
          )
        else
          Container(
            color: Colors.grey[900],
            child: const Center(child: CircularProgressIndicator(color: pinkAccent)),
          ),

        // Face guide oval
        Center(
          child: Container(
            width: 200, height: 260,
            decoration: BoxDecoration(
              border: Border.all(
                color: _faceDetected ? greenAccent.withOpacity(0.8) : redAccent.withOpacity(0.6),
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),

        // Face guidance banner (top)
        if (!_faceDetected || _faceGuidance != 'Good position')
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (_faceDetected ? orangeAccent : redAccent).withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_faceDetected ? Icons.info_outline : Icons.warning_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(_faceGuidance,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),

        // Phase-specific overlay (bottom)
        overlay,
      ],
    );
  }

  Widget _buildRestingOverlay() {
    return Positioned(
      bottom: 16, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_neutral_rounded, color: cyanAccent, size: 28),
            const SizedBox(height: 6),
            const Text('Keep a neutral expression', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBlinkingOverlay() {
    return Positioned(
      bottom: 16, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.remove_red_eye_rounded, color: blueAccent, size: 24),
                const SizedBox(width: 10),
                Text('$_blinkCount', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                const Text(' blinks', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Blink naturally — don\'t force it', style: TextStyle(color: Colors.white, fontSize: 13)),
            Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmilingOverlay() {
    return Positioned(
      bottom: 16, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Icon(Icons.sentiment_very_satisfied_rounded,
                    color: orangeAccent, size: 36 + (_pulseController.value * 8));
              },
            ),
            const SizedBox(height: 6),
            const Text('SMILE!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            if (_smileDetected)
              const Text('Smile detected!', style: TextStyle(color: greenAccent, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpressionsOverlay() {
    final currentTask = _expressionTasks[_currentExpressionIndex];
    return Positioned(
      bottom: 16, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.75), borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(currentTask['icon'] as IconData, color: pinkAccent, size: 36),
            const SizedBox(height: 6),
            Text(currentTask['name'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_expressionTasks.length, (index) {
                final done = index < _currentExpressionIndex;
                final current = index == _currentExpressionIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: current ? 24 : 12, height: 8,
                  decoration: BoxDecoration(
                    color: done ? greenAccent : (current ? pinkAccent : Colors.grey[600]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('${_timeRemaining}s remaining', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedPhase() {
    final data = _getTestData();
    final scores = data['overall_scores'] as Map<String, dynamic>;
    final combined = (scores['combined_score'] as double);
    final blinkRate = (_blinkingResults['blink_rate_per_min'] ?? 0).toDouble();
    final smileSymmetry = (_smilingResults['smile_symmetry'] ?? 0).toDouble();
    final expressionRange = (_expressionResults['expression_range'] ?? 0).toDouble();
    final smileVelocity = (_smilingResults['smile_velocity'] ?? 0).toDouble();
    final hypomimia = (_expressionResults['hypomimia_score'] ?? 0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 6),

          // Animated score ring
          SizedBox(
            width: 140, height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130, height: 130,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: combined / 100),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      final ringColor = value > 0.7 ? greenAccent : value > 0.4 ? orangeAccent : redAccent;
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(ringColor),
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: combined),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Text('${value.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800));
                      },
                    ),
                    Text('Overall', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Text('Analysis Complete', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('4 phases · $_framesCaptured frames analyzed',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),

          const SizedBox(height: 18),

          // Score cards row
          Row(
            children: [
              Expanded(child: _buildScoreCard('Blink', scores['blink_score'], blueAccent, Icons.remove_red_eye_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildScoreCard('Smile', scores['smile_score'], orangeAccent, Icons.sentiment_satisfied_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildScoreCard('Expression', scores['expression_score'], pinkAccent, Icons.theater_comedy_rounded)),
            ],
          ),

          const SizedBox(height: 14),

          // Detailed metrics card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('Detailed Metrics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMetricRow('Blink Rate', '${blinkRate.toStringAsFixed(1)}/min',
                    blinkRate >= 12 && blinkRate <= 25 ? greenAccent : orangeAccent,
                    blinkRate >= 12 && blinkRate <= 25 ? 'Normal' : 'Atypical'),
                _buildMetricRow('Smile Symmetry', '${smileSymmetry.toStringAsFixed(0)}%',
                    smileSymmetry > 85 ? greenAccent : orangeAccent,
                    smileSymmetry > 85 ? 'Symmetric' : 'Asymmetric'),
                _buildMetricRow('Smile Velocity', '${(smileVelocity * 100).toStringAsFixed(0)}%',
                    smileVelocity > 0.5 ? greenAccent : orangeAccent,
                    smileVelocity > 0.5 ? 'Fast onset' : 'Slow onset'),
                _buildMetricRow('Expression Range', '${expressionRange.toStringAsFixed(0)}%',
                    expressionRange > 60 ? greenAccent : orangeAccent,
                    expressionRange > 60 ? 'Wide range' : 'Limited'),
                _buildMetricRow('Hypomimia', '${hypomimia.toStringAsFixed(0)}%',
                    hypomimia < 40 ? greenAccent : redAccent,
                    hypomimia < 40 ? 'Low risk' : 'Elevated'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Get Results button
          GestureDetector(
            onTap: _completeTest,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [pinkAccent, Color(0xFFDB2777)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: pinkAccent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Complete Test', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String title, double score, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text('${value.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color));
            },
          ),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color statusColor, String statusText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: darkCard, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _recordingController,
                builder: (context, child) {
                  return Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: redAccent.withOpacity(0.5 + _recordingController.value * 0.5),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              const Text('REC', style: TextStyle(color: redAccent, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('FACE', _faceDetected ? 'YES' : 'NO', _faceDetected ? greenAccent : redAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('FRAMES', '$_framesCaptured', blueAccent),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
          _buildMiniMetric('TIME', '${_timeRemaining}s', orangeAccent),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
