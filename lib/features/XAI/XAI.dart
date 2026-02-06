import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class XAIScreen extends StatefulWidget {
  const XAIScreen({super.key});

  @override
  State<XAIScreen> createState() => _XAIScreenState();
}

class _XAIScreenState extends State<XAIScreen> with TickerProviderStateMixin {
  late AnimationController _pageController;
  late AnimationController _pulseController;
  int _selectedNavIndex = 3;
  int _selectedModuleIndex = 0;

  Map<String, dynamic>? _resultData;
bool _isLoading = true;
  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color yellowAccent = Color(0xFFEAB308);

  // Analysis modules with unique data for each
  late List<AnalysisModule> modules;

  @override
  void initState() {
    super.initState();
    _initializeModules();
    
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    // Get result from arguments or load latest
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['result'] != null) {
      setState(() {
        _resultData = args['result'];
        _isLoading = false;
      });
      _initializeModulesFromData();
    } else {
      _loadLatestResult();
    }
  });
  }
Future<void> _loadLatestResult() async {
  // Load from user dashboard or latest session
  final result = await ApiService.getUserDashboard();
  
  if (mounted) {
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _resultData = result['data'];
      }
    });
    _initializeModulesFromData();
  }
}

void _initializeModulesFromData() {
  // If we have XAI data from result, use it
  // Otherwise use default/placeholder modules
  if (_resultData != null && _resultData!['xai_explanation'] != null) {
    // Parse XAI data and create modules dynamically
    // For now, use existing _initializeModules with hardcoded data
  }
  _initializeModules();
}
  void _initializeModules() {
    modules = [
      // Speech Module
      AnalysisModule(
        name: 'Speech',
        icon: Icons.mic_rounded,
        color: blueAccent,
        bgColor: const Color(0xFFDBEAFE),
        saliencyTitle: 'Saliency Map: Speech Analysis',
        saliencyDescription: 'Speech spectrogram with highlighted pause regions',
        saliencyLegend: 'Red zones = Abnormal pauses (>2s) • Yellow = Moderate pauses',
        visualizationType: 'spectrogram',
        shapValues: [
          SHAPValue(name: 'Speech Pauses', value: 0.24, level: 'High', color: redAccent),
          SHAPValue(name: 'Pause Duration', value: 0.18, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Voice Tremor', value: 0.15, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Articulation Rate', value: 0.12, level: 'Low', color: greenAccent),
          SHAPValue(name: 'Pitch Variance', value: 0.08, level: 'Low', color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Pauses', value: 0.85),
          FeatureImportance(name: 'Tremor', value: 0.65),
          FeatureImportance(name: 'Pitch', value: 0.50),
          FeatureImportance(name: 'Rate', value: 0.40),
          FeatureImportance(name: 'Clarity', value: 0.30),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Speech pauses (24% contribution):',
            description: 'Detected longer than normal pauses during story recall',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Pause duration (18% contribution):',
            description: 'Average pause length of 2.3s vs normal 1.2s',
            color: orangeAccent,
          ),
          InterpretationPoint(
            title: 'Voice tremor (15% contribution):',
            description: 'Slight irregularities in sustained vowel test',
            color: orangeAccent,
          ),
        ],
      ),
      
      // Motor Module
      AnalysisModule(
        name: 'Motor',
        icon: Icons.pan_tool_rounded,
        color: orangeAccent,
        bgColor: const Color(0xFFFFF7ED),
        saliencyTitle: 'Saliency Map: Motor Analysis',
        saliencyDescription: 'Spiral drawing analysis with tremor detection',
        saliencyLegend: 'Red dots = High tremor • Yellow = Moderate irregularity',
        visualizationType: 'spiral',
        shapValues: [
          SHAPValue(name: 'Tremor Amplitude', value: 0.28, level: 'High', color: redAccent),
          SHAPValue(name: 'Drawing Speed', value: 0.20, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Line Smoothness', value: 0.16, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Pressure Variance', value: 0.10, level: 'Low', color: greenAccent),
          SHAPValue(name: 'Spiral Accuracy', value: 0.09, level: 'Low', color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Tremor', value: 0.90),
          FeatureImportance(name: 'Speed', value: 0.70),
          FeatureImportance(name: 'Smooth', value: 0.55),
          FeatureImportance(name: 'Press', value: 0.35),
          FeatureImportance(name: 'Accuracy', value: 0.28),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Tremor amplitude (28% contribution):',
            description: 'Detected 3.2mm average deviation in spiral drawing',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Drawing speed (20% contribution):',
            description: 'Slower completion time: 45s vs normal 30s',
            color: orangeAccent,
          ),
          InterpretationPoint(
            title: 'Line smoothness (16% contribution):',
            description: 'Irregular pen strokes detected in curved sections',
            color: orangeAccent,
          ),
        ],
      ),
      
      // Cognitive Module
      AnalysisModule(
        name: 'Cognitive',
        icon: Icons.psychology_rounded,
        color: purpleAccent,
        bgColor: const Color(0xFFF3E8FF),
        saliencyTitle: 'Saliency Map: Cognitive Analysis',
        saliencyDescription: 'Memory recall test response timing',
        saliencyLegend: 'Low bars = Delayed responses indicating potential memory issues',
        visualizationType: 'bars',
        shapValues: [
          SHAPValue(name: 'Response Time', value: 0.26, level: 'High', color: redAccent),
          SHAPValue(name: 'Recall Accuracy', value: 0.19, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Stroop Interference', value: 0.17, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Working Memory', value: 0.11, level: 'Low', color: greenAccent),
          SHAPValue(name: 'Attention Span', value: 0.07, level: 'Low', color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Response', value: 0.88),
          FeatureImportance(name: 'Recall', value: 0.68),
          FeatureImportance(name: 'Stroop', value: 0.58),
          FeatureImportance(name: 'Memory', value: 0.38),
          FeatureImportance(name: 'Attention', value: 0.25),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Response time (26% contribution):',
            description: 'Average response delay of 1.8s vs normal 0.9s',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Recall accuracy (19% contribution):',
            description: 'Word list recall: 6/15 words vs normal 10/15',
            color: orangeAccent,
          ),
          InterpretationPoint(
            title: 'Stroop interference (17% contribution):',
            description: 'Higher error rate in color-word conflict tasks',
            color: orangeAccent,
          ),
        ],
      ),
      
      // Facial Module
      AnalysisModule(
        name: 'Facial',
        icon: Icons.face_rounded,
        color: pinkAccent,
        bgColor: const Color(0xFFFCE7F3),
        saliencyTitle: 'Saliency Map: Facial Analysis',
        saliencyDescription: 'Expression and micro-movement detection',
        saliencyLegend: 'Highlighted regions = Areas of reduced facial movement',
        visualizationType: 'face',
        shapValues: [
          SHAPValue(name: 'Blink Rate', value: 0.22, level: 'High', color: redAccent),
          SHAPValue(name: 'Smile Velocity', value: 0.19, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Expression Range', value: 0.14, level: 'Medium', color: orangeAccent),
          SHAPValue(name: 'Eye Movement', value: 0.11, level: 'Low', color: greenAccent),
          SHAPValue(name: 'Micro Expressions', value: 0.08, level: 'Low', color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Blink', value: 0.82),
          FeatureImportance(name: 'Smile', value: 0.66),
          FeatureImportance(name: 'Express', value: 0.50),
          FeatureImportance(name: 'Eyes', value: 0.38),
          FeatureImportance(name: 'Micro', value: 0.28),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Blink rate (22% contribution):',
            description: 'Reduced blink frequency: 8/min vs normal 15/min',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Smile velocity (19% contribution):',
            description: 'Slower smile formation detected (hypomimia indicator)',
            color: orangeAccent,
          ),
          InterpretationPoint(
            title: 'Expression range (14% contribution):',
            description: 'Limited facial expression variation during tasks',
            color: orangeAccent,
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    HapticFeedback.selectionClick();
    
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/tests');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/reports');
        break;
      case 3:
        setState(() => _selectedNavIndex = index);
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  AnalysisModule get selectedModule => modules[_selectedModuleIndex];

  @override
  Widget build(BuildContext context) {
   if (_isLoading) {
    return Scaffold(
      backgroundColor: bgColor,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  return  Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildTransparencyCard(),
                    const SizedBox(height: 24),
                    _buildModuleSelector(),
                    const SizedBox(height: 20),
                    _buildSaliencyMapCard(),
                    const SizedBox(height: 20),
                    _buildSHAPValuesCard(),
                    const SizedBox(height: 20),
                    _buildFeatureImportanceCard(),
                    const SizedBox(height: 20),
                    _buildAIInterpretationCard(),
                    const SizedBox(height: 20),
                    _buildExportButton(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explainable AI',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Understanding AI predictions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransparencyCard() {
    return _buildAnimatedWidget(
      delay: 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                selectedModule.bgColor.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selectedModule.color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: selectedModule.color.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selectedModule.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: selectedModule.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transparency & Trust',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Our AI uses saliency maps and SHAP values to show exactly which features influenced your risk assessment.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleSelector() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select Analysis Module',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                final isSelected = _selectedModuleIndex == index;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedModuleIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          module.color,
                          module.color.withOpacity(0.8),
                        ],
                      ) : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected 
                            ? module.color 
                            : Colors.black.withOpacity(0.08),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: module.color.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ] : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.white.withOpacity(0.25) 
                                : module.bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            module.icon,
                            color: isSelected ? Colors.white : module.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          module.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected 
                                ? Colors.white 
                                : Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaliencyMapCard() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedModule.saliencyTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedModule.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: selectedModule.color,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selectedModule.saliencyDescription,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              _buildVisualization(selectedModule),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedModule.bgColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selectedModule.color.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red, Colors.yellow],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedModule.saliencyLegend,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualization(AnalysisModule module) {
    switch (module.visualizationType) {
      case 'spectrogram':
        return _buildSpectrogramVisualization();
      case 'spiral':
        return _buildSpiralVisualization();
      case 'bars':
        return _buildBarsVisualization();
      case 'face':
        return _buildFaceVisualization();
      default:
        return _buildSpectrogramVisualization();
    }
  }

  Widget _buildSpectrogramVisualization() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F),
                const Color(0xFF2D5A87),
                const Color(0xFF1E3A5F),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: blueAccent.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Animated gradient overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: SpectrogramPainter(
                      animation: _pulseController.value,
                    ),
                  ),
                ),
                // Highlight zones
                Positioned(
                  left: 60,
                  top: 30,
                  child: Container(
                    width: 50,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.red.withOpacity(0.6),
                          Colors.red.withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  right: 80,
                  top: 40,
                  child: Container(
                    width: 60,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.orange.withOpacity(0.7),
                          Colors.orange.withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Positioned(
                  left: 150,
                  top: 50,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.yellow.withOpacity(0.5),
                          Colors.yellow.withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpiralVisualization() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: orangeAccent.withOpacity(0.2)),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(120, 120),
          painter: ImprovedSpiralPainter(),
        ),
      ),
    );
  }

  Widget _buildBarsVisualization() {
    final barData = [0.95, 0.75, 0.45, 0.35, 0.70, 0.85, 0.25, 0.55];
    final barColors = [
      greenAccent, greenAccent, yellowAccent, redAccent, 
      greenAccent, greenAccent, redAccent, yellowAccent
    ];
    
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            softLavender.withOpacity(0.5),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(barData.length, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final heightMultiplier = 0.95 + (_pulseController.value * 0.05);
              return Container(
                width: 28,
                height: 100 * barData[index] * heightMultiplier,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      barColors[index],
                      barColors[index].withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: barColors[index].withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildFaceVisualization() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pinkAccent.withOpacity(0.1),
            softLavender.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pinkAccent.withOpacity(0.2)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Face outline
          Icon(
            Icons.face_rounded,
            size: 90,
            color: pinkAccent.withOpacity(0.3),
          ),
          // Highlight areas
          Positioned(
            top: 35,
            left: 95,
            child: _buildHighlightDot(12, Colors.red.withOpacity(0.6)),
          ),
          Positioned(
            top: 35,
            right: 95,
            child: _buildHighlightDot(12, Colors.red.withOpacity(0.6)),
          ),
          Positioned(
            bottom: 45,
            child: _buildHighlightDot(16, Colors.orange.withOpacity(0.5)),
          ),
          // Animated pulse rings
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Positioned(
                top: 30,
                left: 90,
                child: Container(
                  width: 22 + (_pulseController.value * 8),
                  height: 22 + (_pulseController.value * 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.withOpacity(0.4 - _pulseController.value * 0.3),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightDot(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSHAPValuesCard() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedModule.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bar_chart_rounded,
                      color: selectedModule.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SHAP Values (Feature Contribution)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'How each feature impacts the risk prediction',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...selectedModule.shapValues.map((shap) => _buildSHAPRow(shap)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSHAPRow(SHAPValue shap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  shap.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                shap.value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: shap.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shap.level,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: shap.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: constraints.maxWidth * (shap.value / 0.30),
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            shap.color.withOpacity(0.8),
                            shap.color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: shap.color.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureImportanceCard() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Feature Importance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ranking of biomarkers by prediction impact',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 130,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: selectedModule.featureImportance.asMap().entries.map((entry) {
                    final index = entry.key;
                    final feature = entry.value;
                    final colors = [
                      [selectedModule.color, selectedModule.color.withOpacity(0.6)],
                    ][0];
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 40,
                          height: 100 * feature.value,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                selectedModule.color,
                                selectedModule.color.withOpacity(0.5),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: selectedModule.color.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feature.name,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIInterpretationCard() {
    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: darkCard.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: greenAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Interpretation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Your risk assessment is primarily influenced by:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 14),
              ...selectedModule.interpretationPoints.map((point) => _buildInterpretationPoint(point)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterpretationPoint(InterpretationPoint point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: point.color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: point.color.withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: point.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  point.description,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return _buildAnimatedWidget(
      delay: 0.35,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  selectedModule.color,
                  selectedModule.color.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: selectedModule.color.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Export Explainability Report',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.assignment_outlined, 'Tests'),
              _buildNavItem(2, Icons.analytics_outlined, 'Reports'),
              _buildNavItem(3, Icons.auto_awesome_rounded, 'XAI'),
              _buildNavItem(4, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? darkCard : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black38,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWidget({required double delay, required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _pageController,
        curve: Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _pageController,
          curve: Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}

// Data models
class AnalysisModule {
  final String name;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String saliencyTitle;
  final String saliencyDescription;
  final String saliencyLegend;
  final String visualizationType;
  final List<SHAPValue> shapValues;
  final List<FeatureImportance> featureImportance;
  final List<InterpretationPoint> interpretationPoints;

  AnalysisModule({
    required this.name,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.saliencyTitle,
    required this.saliencyDescription,
    required this.saliencyLegend,
    required this.visualizationType,
    required this.shapValues,
    required this.featureImportance,
    required this.interpretationPoints,
  });
}

class SHAPValue {
  final String name;
  final double value;
  final String level;
  final Color color;

  SHAPValue({
    required this.name,
    required this.value,
    required this.level,
    required this.color,
  });
}

class FeatureImportance {
  final String name;
  final double value;

  FeatureImportance({
    required this.name,
    required this.value,
  });
}

class InterpretationPoint {
  final String title;
  final String description;
  final Color color;

  InterpretationPoint({
    required this.title,
    required this.description,
    required this.color,
  });
}

// Custom painters
class SpectrogramPainter extends CustomPainter {
  final double animation;

  SpectrogramPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw animated wave layers
    for (int layer = 0; layer < 6; layer++) {
      final path = Path();
      final baseY = size.height * (0.2 + layer * 0.12);
      final amplitude = 15.0 + layer * 5;
      final frequency = 0.02 + layer * 0.005;
      final phaseShift = animation * math.pi * 2 + layer * 0.5;

      path.moveTo(0, baseY);
      
      for (double x = 0; x <= size.width; x++) {
        final y = baseY + math.sin(x * frequency + phaseShift) * amplitude;
        path.lineTo(x, y);
      }
      
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      // Gradient colors based on layer
      final colors = [
        Colors.cyan.withOpacity(0.3 - layer * 0.04),
        Colors.blue.withOpacity(0.25 - layer * 0.03),
        Colors.purple.withOpacity(0.2 - layer * 0.02),
      ];
      
      paint.color = colors[layer % 3];
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SpectrogramPainter oldDelegate) => 
      oldDelegate.animation != animation;
}

class ImprovedSpiralPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final turns = 3.5;
    final maxRadius = size.width / 2 - 10;
    final totalPoints = (turns * 2 * math.pi / 0.05).toInt();

    Path path = Path();
    
    for (int i = 0; i <= totalPoints; i++) {
      final angle = i * 0.05;
      final radius = (angle / (turns * 2 * math.pi)) * maxRadius;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw gradient spiral
    final gradientShader = SweepGradient(
      colors: [
        Colors.green,
        Colors.yellow.shade600,
        Colors.orange,
        Colors.red,
        Colors.orange,
        Colors.yellow.shade600,
        Colors.green,
      ],
      stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    paint.shader = gradientShader;
    canvas.drawPath(path, paint);

    // Draw tremor dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    
    // Red dots (high tremor)
    dotPaint.color = Colors.red;
    canvas.drawCircle(Offset(center.dx + 25, center.dy - 20), 6, dotPaint);
    canvas.drawCircle(Offset(center.dx - 30, center.dy + 25), 5, dotPaint);
    
    // Yellow dots (moderate tremor)
    dotPaint.color = Colors.yellow.shade700;
    canvas.drawCircle(Offset(center.dx + 38, center.dy + 8), 4, dotPaint);
    canvas.drawCircle(Offset(center.dx - 15, center.dy - 35), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}