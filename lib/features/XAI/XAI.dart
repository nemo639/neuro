import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/shimmer_loading.dart';

class XAIScreen extends StatefulWidget {
  const XAIScreen({super.key});

  @override
  State<XAIScreen> createState() => _XAIScreenState();
}

class _XAIScreenState extends State<XAIScreen> with TickerProviderStateMixin {
  late AnimationController _pageController;
  late AnimationController _pulseController;
  int _selectedNavIndex = 2;
  int _selectedModuleIndex = 0;
  int _selectedMethodIndex = 0;

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
  static const Color indigoAccent = Color(0xFF6366F1);

  // XAI method definitions
  static final List<_XAIMethod> _xaiMethods = [
    _XAIMethod('SHAP', Icons.bar_chart_rounded, blueAccent),
    _XAIMethod('GradCAM', Icons.gradient_rounded, purpleAccent),
    _XAIMethod('LIME', Icons.science_rounded, greenAccent),
    _XAIMethod('Integrated\nGradients', Icons.timeline_rounded, orangeAccent),
    _XAIMethod('What-If', Icons.compare_arrows_rounded, tealAccent),
    _XAIMethod('Attention', Icons.center_focus_strong_rounded, pinkAccent),
    _XAIMethod('Clinical', Icons.medical_information_rounded, indigoAccent),
  ];

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
    // Fetch latest results per category with full XAI explanations
    final result = await ApiService.getLatestTestResults();
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
    if (_resultData == null) return;

    // Support two data shapes:
    // 1. Post-test: {xai_explanation: {cognitive: {...}, speech: {...}}}
    // 2. Latest-results endpoint: {cognitive: {xai_explanation: {...}}, speech: {...}}
    Map<String, dynamic>? xai;

    if (_resultData!.containsKey('xai_explanation')) {
      // Shape 1: single result with nested per-category XAI
      xai = _resultData!['xai_explanation'] as Map<String, dynamic>?;
    } else {
      // Shape 2: per-category results, each with its own xai_explanation
      xai = {};
      for (final cat in ['cognitive', 'speech', 'motor', 'facial']) {
        final catData = _resultData![cat] as Map<String, dynamic>?;
        if (catData != null && catData['xai_explanation'] != null) {
          xai[cat] = catData['xai_explanation'] as Map<String, dynamic>;
        }
      }
      if (xai.isEmpty) xai = null;
    }

    if (xai == null) return;

    // Parse per-category XAI data
    for (int i = 0; i < modules.length; i++) {
      final catName = modules[i].name.toLowerCase();
      final catXai = xai[catName] as Map<String, dynamic>?;
      if (catXai == null) continue;

      // Parse SHAP values
      final rawShap = catXai['shap_values'] as List?;
      if (rawShap != null && rawShap.isNotEmpty) {
        modules[i].shapValues = rawShap.take(6).map((s) {
          final val = (s['value'] ?? s['contribution'] ?? 0).toDouble();
          final level = s['level'] ?? 'Low';
          return SHAPValue(
            name: s['name'] ?? '',
            value: val.abs(),
            level: level,
            color: level == 'High'
                ? redAccent
                : level == 'Medium'
                    ? orangeAccent
                    : greenAccent,
          );
        }).toList();
      }

      // Parse feature importance
      final rawFI = catXai['feature_importance'] as List?;
      if (rawFI != null && rawFI.isNotEmpty) {
        modules[i].featureImportance = rawFI.take(6).map((f) {
          return FeatureImportance(
            name: f['name'] ?? '',
            value: (f['value'] ?? 0).toDouble(),
          );
        }).toList();
      }

      // Parse interpretations
      final rawInterp = catXai['interpretations'] as List?;
      if (rawInterp != null && rawInterp.isNotEmpty) {
        modules[i].interpretationPoints = rawInterp.take(4).map((ip) {
          final severity = ip['severity'] ?? 'info';
          return InterpretationPoint(
            title: ip['title'] ?? '',
            description: ip['description'] ?? '',
            recommendation: ip['recommendation'] ?? '',
            severity: severity,
            color: severity == 'warning'
                ? redAccent
                : severity == 'positive'
                    ? greenAccent
                    : orangeAccent,
          );
        }).toList();
      }

      // Parse LIME explanations
      final rawLime = catXai['lime_explanations'] as List?;
      if (rawLime != null && rawLime.isNotEmpty) {
        modules[i].limeValues = rawLime.take(8).map((l) {
          final w = (l['lime_weight'] ?? 0).toDouble();
          final dir = l['direction'] ?? 'risk';
          return LIMEValue(
            name: l['feature'] ?? '',
            weight: w.abs(),
            direction: dir,
            description: l['description'] ?? '',
            color: dir == 'risk' ? redAccent : greenAccent,
          );
        }).toList();
      }

      // Parse Integrated Gradients
      final rawIG = catXai['integrated_gradients'] as List?;
      if (rawIG != null && rawIG.isNotEmpty) {
        modules[i].igAttributions = rawIG.take(8).map((ig) {
          final attr = (ig['attribution'] ?? 0).toDouble();
          final dir = ig['direction'] ?? 'risk';
          return IGAttribution(
            name: ig['feature'] ?? '',
            attribution: attr.abs(),
            importance: (ig['importance'] ?? 0).toDouble(),
            direction: dir,
            color: dir == 'risk' ? redAccent : greenAccent,
          );
        }).toList();
      }

      // Parse Counterfactual analysis
      final rawCF = catXai['counterfactual_analysis'] as Map<String, dynamic>?;
      if (rawCF != null) {
        final scenarios = rawCF['counterfactuals'] as List? ?? [];
        modules[i].counterfactuals = scenarios.take(5).map((cf) {
          return CounterfactualScenario(
            feature: cf['feature_label'] ?? cf['feature'] ?? '',
            currentValue: (cf['current_value'] ?? 0).toDouble(),
            targetValue: (cf['target_value'] ?? 0).toDouble(),
            changeDirection: cf['change_direction'] ?? 'increase',
            riskReduction: (cf['estimated_risk_reduction'] ?? 0).toDouble(),
            description: cf['description'] ?? '',
            feasibility: cf['feasibility'] ?? 'unknown',
          );
        }).toList();

        final actions = rawCF['actionable_insights'] as List? ?? [];
        modules[i].actionableInsights = actions.take(4).map((a) {
          return ActionableInsight(
            feature: a['feature'] ?? '',
            recommendation: a['recommendation'] ?? '',
            priority: a['priority'] ?? 'medium',
            benefit: a['estimated_benefit'] ?? '',
          );
        }).toList();
      }

      // Parse Attention data
      final rawAttn = catXai['attention_analysis'] as Map<String, dynamic>?;
      if (rawAttn != null) {
        final bars = rawAttn['data'] as List? ?? [];
        modules[i].attentionBars = bars.take(8).map((b) {
          return AttentionBar(
            feature: b['feature'] ?? '',
            weight: (b['attention_weight'] ?? 0).toDouble().abs(),
            importance: (b['relative_importance'] ?? 0).toDouble(),
            activated: b['activated'] ?? false,
            category: b['category'] ?? 'other',
            color: (b['activated'] ?? false) ? orangeAccent : Colors.grey,
          );
        }).toList();
        modules[i].attentionSummary =
            rawAttn['summary'] ?? 'Attention data available';
      }

      final rawAttnSummary =
          catXai['attention_summary'] as Map<String, dynamic>?;
      if (rawAttnSummary != null) {
        modules[i].attentionNarrative =
            rawAttnSummary['narrative'] ?? modules[i].attentionSummary;
      }

      // Parse summary and confidence
      modules[i].summary = catXai['summary'] as String? ?? modules[i].summary;
      modules[i].confidence =
          (catXai['confidence'] ?? modules[i].confidence).toDouble();

      // Mark this module as having real data
      modules[i].hasRealData = true;

      // Track which XAI methods have real data
      // 0=SHAP, 1=GradCAM, 2=LIME, 3=IG, 4=What-If, 5=Attention, 6=Clinical
      final methods = <int>{};
      if (rawShap != null && rawShap.isNotEmpty) methods.addAll([0]); // SHAP + Feature Importance
      if (catXai['saliency_data'] != null) methods.add(1); // GradCAM
      if (rawLime != null && rawLime.isNotEmpty) methods.add(2); // LIME
      if (rawIG != null && rawIG.isNotEmpty) methods.add(3); // IG
      if (rawCF != null) methods.add(4); // What-If
      if (rawAttn != null) methods.add(5); // Attention
      if (rawInterp != null && rawInterp.isNotEmpty) methods.add(6); // Clinical
      // Always include Clinical if we have any real data
      if (methods.isNotEmpty) methods.add(6);
      modules[i].availableMethods = methods;
    }

    // Auto-select first module that has real data
    final firstReal = modules.indexWhere((m) => m.hasRealData);
    if (firstReal >= 0 && !modules[_selectedModuleIndex].hasRealData) {
      _selectedModuleIndex = firstReal;
    }
    // Auto-select first available method for the selected module
    _autoSelectMethod();

    if (mounted) setState(() {});
  }

  /// Select the first available XAI method for the current module.
  void _autoSelectMethod() {
    final methods = selectedModule.availableMethods;
    if (methods.isNotEmpty && !methods.contains(_selectedMethodIndex)) {
      _selectedMethodIndex = methods.reduce((a, b) => a < b ? a : b);
    }
  }

  void _initializeModules() {
    modules = [
      // Speech Module
      AnalysisModule(
        name: 'Speech',
        icon: Icons.mic_rounded,
        color: blueAccent,
        bgColor: const Color(0xFFDBEAFE),
        saliencyTitle: 'Audio Feature Saliency',
        saliencyDescription:
            'Speech waveform analysis with highlighted pause regions and prosodic markers',
        saliencyLegend:
            'Red = Abnormal pauses (>2s)  |  Yellow = Moderate pauses  |  Green = Normal',
        visualizationType: 'spectrogram',
        summary:
            'Speech analysis evaluates voice quality, fluency, and recall from audio recordings.',
        confidence: 0.72,
        shapValues: [
          SHAPValue(
              name: 'Speech Pauses',
              value: 0.24,
              level: 'High',
              color: redAccent),
          SHAPValue(
              name: 'Pause Duration',
              value: 0.18,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Voice Stability',
              value: 0.15,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Speech Rate',
              value: 0.12,
              level: 'Low',
              color: greenAccent),
          SHAPValue(
              name: 'Story Recall',
              value: 0.08,
              level: 'Low',
              color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Pauses', value: 0.85),
          FeatureImportance(name: 'Stability', value: 0.65),
          FeatureImportance(name: 'Rate', value: 0.50),
          FeatureImportance(name: 'Recall', value: 0.40),
          FeatureImportance(name: 'Vowel', value: 0.30),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Speech Pause Pattern',
            description:
                'Longer than normal pauses during story recall may indicate word-finding difficulty.',
            recommendation: 'Monitor pause patterns over time.',
            severity: 'warning',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Voice Stability',
            description:
                'Slight irregularities in sustained vowel test detected.',
            recommendation: 'Voice therapy exercises may help.',
            severity: 'info',
            color: orangeAccent,
          ),
        ],
        limeValues: [
          LIMEValue(
              name: 'pause_rate',
              weight: 0.18,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
          LIMEValue(
              name: 'speech_rate',
              weight: 0.14,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
          LIMEValue(
              name: 'vowel_stability',
              weight: 0.11,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
          LIMEValue(
              name: 'story_recall_accuracy',
              weight: 0.09,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
          LIMEValue(
              name: 'jitter',
              weight: 0.07,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
        ],
        igAttributions: [
          IGAttribution(
              name: 'pause_count',
              attribution: 0.22,
              importance: 0.22,
              direction: 'risk',
              color: redAccent),
          IGAttribution(
              name: 'story_recall_accuracy',
              attribution: 0.17,
              importance: 0.17,
              direction: 'protective',
              color: greenAccent),
          IGAttribution(
              name: 'vowel_stability',
              attribution: 0.13,
              importance: 0.13,
              direction: 'protective',
              color: greenAccent),
          IGAttribution(
              name: 'shimmer',
              attribution: 0.10,
              importance: 0.10,
              direction: 'risk',
              color: redAccent),
        ],
        counterfactuals: [
          CounterfactualScenario(
            feature: 'Speech Rate',
            currentValue: 95,
            targetValue: 130,
            changeDirection: 'increase',
            riskReduction: 8.5,
            description: 'Increase Speech Rate from 95 to 130 wpm',
            feasibility: 'modifiable',
          ),
          CounterfactualScenario(
            feature: 'Pause Count',
            currentValue: 12,
            targetValue: 5,
            changeDirection: 'decrease',
            riskReduction: 6.2,
            description: 'Reduce speech pauses from 12 to 5',
            feasibility: 'modifiable',
          ),
        ],
        actionableInsights: [
          ActionableInsight(
            feature: 'Speech Rate',
            recommendation:
                'Practice reading aloud and conversational exercises to improve fluency.',
            priority: 'medium',
            benefit: '~9% risk reduction',
          ),
          ActionableInsight(
            feature: 'Story Recall',
            recommendation:
                'Memory training exercises and mnemonic strategies may improve recall.',
            priority: 'medium',
            benefit: '~5% risk reduction',
          ),
        ],
        attentionBars: [
          AttentionBar(
              feature: 'pause_rate',
              weight: 0.28,
              importance: 0.22,
              activated: true,
              category: 'speech',
              color: orangeAccent),
          AttentionBar(
              feature: 'speech_rate',
              weight: 0.19,
              importance: 0.15,
              activated: true,
              category: 'speech',
              color: orangeAccent),
          AttentionBar(
              feature: 'vowel_stability',
              weight: 0.15,
              importance: 0.12,
              activated: true,
              category: 'voice_quality',
              color: orangeAccent),
          AttentionBar(
              feature: 'shimmer',
              weight: 0.09,
              importance: 0.07,
              activated: false,
              category: 'voice_quality',
              color: Colors.grey),
        ],
        attentionSummary: 'Model focuses most on: pause_rate, speech_rate',
        attentionNarrative:
            'For speech assessment, the model\'s attention mechanism focused primarily on pause patterns and fluency features. The attention pattern is consistent with AD-related biomarker emphasis.',
      ),

      // Motor Module
      AnalysisModule(
        name: 'Motor',
        icon: Icons.gesture_rounded,
        color: orangeAccent,
        bgColor: const Color(0xFFFFF7ED),
        saliencyTitle: 'Drawing Saliency Map',
        saliencyDescription:
            'Spiral & meander drawing analysis with tremor detection overlay',
        saliencyLegend:
            'Red dots = High tremor  |  Yellow = Moderate irregularity  |  Green = Normal',
        visualizationType: 'spiral',
        summary:
            'Motor analysis evaluates drawing precision, tremor, tapping speed and fatigue.',
        confidence: 0.78,
        shapValues: [
          SHAPValue(
              name: 'Tremor Amplitude',
              value: 0.28,
              level: 'High',
              color: redAccent),
          SHAPValue(
              name: 'Drawing Speed',
              value: 0.20,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Line Smoothness',
              value: 0.16,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Tapping Regularity',
              value: 0.10,
              level: 'Low',
              color: greenAccent),
          SHAPValue(
              name: 'Motor Fatigue',
              value: 0.09,
              level: 'Low',
              color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Tremor', value: 0.90),
          FeatureImportance(name: 'Speed', value: 0.70),
          FeatureImportance(name: 'Smooth', value: 0.55),
          FeatureImportance(name: 'Tapping', value: 0.35),
          FeatureImportance(name: 'Fatigue', value: 0.28),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Tremor Detection',
            description:
                'Detected deviation in spiral drawing consistent with motor tremor.',
            recommendation: 'Movement disorder evaluation recommended.',
            severity: 'warning',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Drawing Speed',
            description: 'Slower drawing completion time compared to baseline.',
            recommendation: 'Monitor motor speed over time.',
            severity: 'info',
            color: orangeAccent,
          ),
        ],
        limeValues: [
          LIMEValue(
              name: 'spiral_tremor',
              weight: 0.25,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
          LIMEValue(
              name: 'tapping_regularity',
              weight: 0.16,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
          LIMEValue(
              name: 'tapping_fatigue',
              weight: 0.12,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
          LIMEValue(
              name: 'meander_tremor',
              weight: 0.10,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
        ],
        igAttributions: [
          IGAttribution(
              name: 'spiral_tremor',
              attribution: 0.30,
              importance: 0.30,
              direction: 'risk',
              color: redAccent),
          IGAttribution(
              name: 'tapping_rate',
              attribution: 0.18,
              importance: 0.18,
              direction: 'protective',
              color: greenAccent),
          IGAttribution(
              name: 'spiral_deviation',
              attribution: 0.14,
              importance: 0.14,
              direction: 'risk',
              color: redAccent),
        ],
        counterfactuals: [
          CounterfactualScenario(
            feature: 'Tapping Speed',
            currentValue: 3.8,
            targetValue: 5.5,
            changeDirection: 'increase',
            riskReduction: 7.0,
            description: 'Increase tapping speed from 3.8 to 5.5 taps/s',
            feasibility: 'modifiable',
          ),
          CounterfactualScenario(
            feature: 'Motor Fatigue',
            currentValue: 0.35,
            targetValue: 0.15,
            changeDirection: 'decrease',
            riskReduction: 5.5,
            description: 'Reduce motor fatigue index from 0.35 to 0.15',
            feasibility: 'modifiable',
          ),
        ],
        actionableInsights: [
          ActionableInsight(
            feature: 'Tapping Speed',
            recommendation:
                'Regular fine motor exercises (piano, typing) can improve tapping speed.',
            priority: 'medium',
            benefit: '~7% risk reduction',
          ),
        ],
        attentionBars: [
          AttentionBar(
              feature: 'spiral_tremor',
              weight: 0.32,
              importance: 0.26,
              activated: true,
              category: 'motor',
              color: orangeAccent),
          AttentionBar(
              feature: 'tapping_regularity',
              weight: 0.21,
              importance: 0.17,
              activated: true,
              category: 'motor',
              color: orangeAccent),
          AttentionBar(
              feature: 'tapping_fatigue',
              weight: 0.14,
              importance: 0.11,
              activated: true,
              category: 'motor',
              color: orangeAccent),
        ],
        attentionSummary:
            'Model focuses most on: spiral_tremor, tapping_regularity',
        attentionNarrative:
            'For motor assessment, the model\'s attention mechanism focused primarily on tremor and rhythm features. The attention pattern is consistent with PD-related motor emphasis.',
      ),

      // Cognitive Module
      AnalysisModule(
        name: 'Cognitive',
        icon: Icons.extension_rounded,
        color: purpleAccent,
        bgColor: const Color(0xFFF3E8FF),
        saliencyTitle: 'Cognitive Feature Saliency',
        saliencyDescription:
            'TMT path analysis + Clock Drawing Score + Memory recall performance',
        saliencyLegend:
            'Low bars = Delayed responses  |  Red path = Errors  |  Green = Normal',
        visualizationType: 'bars',
        summary:
            'Cognitive analysis evaluates memory, executive function, attention and visuospatial ability.',
        confidence: 0.68,
        shapValues: [
          SHAPValue(
              name: 'TMT-B Time',
              value: 0.26,
              level: 'High',
              color: redAccent),
          SHAPValue(
              name: 'Recall Accuracy',
              value: 0.19,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Stroop Interference',
              value: 0.17,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Clock Drawing Score',
              value: 0.11,
              level: 'Low',
              color: greenAccent),
          SHAPValue(
              name: 'N-Back Accuracy',
              value: 0.07,
              level: 'Low',
              color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'TMT-B', value: 0.88),
          FeatureImportance(name: 'Recall', value: 0.68),
          FeatureImportance(name: 'Stroop', value: 0.58),
          FeatureImportance(name: 'CDT', value: 0.42),
          FeatureImportance(name: 'N-Back', value: 0.25),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Executive Function',
            description:
                'TMT-B completion time elevated, suggesting difficulty with cognitive flexibility.',
            recommendation:
                'Comprehensive neuropsychological evaluation recommended.',
            severity: 'warning',
            color: redAccent,
          ),
          InterpretationPoint(
            title: 'Memory Recall',
            description:
                'Word list recall below expected range for age group.',
            recommendation: 'Monitor recall performance longitudinally.',
            severity: 'info',
            color: orangeAccent,
          ),
        ],
        limeValues: [
          LIMEValue(
              name: 'recall_accuracy',
              weight: 0.21,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
          LIMEValue(
              name: 'tmt_b_time',
              weight: 0.19,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
          LIMEValue(
              name: 'stroop_accuracy',
              weight: 0.14,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
          LIMEValue(
              name: 'errors_b',
              weight: 0.11,
              direction: 'risk',
              description: 'Increases risk',
              color: redAccent),
          LIMEValue(
              name: 'shulman_score',
              weight: 0.09,
              direction: 'protective',
              description: 'Decreases risk',
              color: greenAccent),
        ],
        igAttributions: [
          IGAttribution(
              name: 'tmt_b_time',
              attribution: 0.25,
              importance: 0.25,
              direction: 'risk',
              color: redAccent),
          IGAttribution(
              name: 'recall_accuracy',
              attribution: 0.20,
              importance: 0.20,
              direction: 'protective',
              color: greenAccent),
          IGAttribution(
              name: 'shulman_score',
              attribution: 0.15,
              importance: 0.15,
              direction: 'protective',
              color: greenAccent),
          IGAttribution(
              name: 'path_efficiency',
              attribution: 0.10,
              importance: 0.10,
              direction: 'protective',
              color: greenAccent),
        ],
        counterfactuals: [
          CounterfactualScenario(
            feature: 'Word Recall',
            currentValue: 0.45,
            targetValue: 0.75,
            changeDirection: 'increase',
            riskReduction: 9.0,
            description: 'Increase recall accuracy from 45% to 75%',
            feasibility: 'partially_modifiable',
          ),
          CounterfactualScenario(
            feature: 'TMT-B Time',
            currentValue: 150,
            targetValue: 90,
            changeDirection: 'decrease',
            riskReduction: 7.5,
            description: 'Reduce TMT-B time from 150s to 90s',
            feasibility: 'not_modifiable',
          ),
        ],
        actionableInsights: [
          ActionableInsight(
            feature: 'Word Recall',
            recommendation:
                'Spaced repetition and association techniques can improve word recall.',
            priority: 'high',
            benefit: '~9% risk reduction',
          ),
          ActionableInsight(
            feature: 'Stroop Accuracy',
            recommendation:
                'Cognitive training with attention exercises may help improve executive function.',
            priority: 'medium',
            benefit: '~5% risk reduction',
          ),
        ],
        attentionBars: [
          AttentionBar(
              feature: 'tmt_b_time',
              weight: 0.28,
              importance: 0.22,
              activated: true,
              category: 'cognitive',
              color: orangeAccent),
          AttentionBar(
              feature: 'recall_accuracy',
              weight: 0.22,
              importance: 0.18,
              activated: true,
              category: 'cognitive',
              color: orangeAccent),
          AttentionBar(
              feature: 'shulman_score',
              weight: 0.16,
              importance: 0.13,
              activated: true,
              category: 'cognitive',
              color: orangeAccent),
          AttentionBar(
              feature: 'stroop_accuracy',
              weight: 0.12,
              importance: 0.10,
              activated: false,
              category: 'cognitive',
              color: Colors.grey),
        ],
        attentionSummary:
            'Model focuses most on: tmt_b_time, recall_accuracy, shulman_score',
        attentionNarrative:
            'For cognitive assessment, the model\'s attention mechanism focused primarily on executive function and memory features. The attention pattern is consistent with AD-related biomarker emphasis.',
      ),

      // Facial Module
      AnalysisModule(
        name: 'Facial',
        icon: Icons.face_retouching_natural_rounded,
        color: pinkAccent,
        bgColor: const Color(0xFFFCE7F3),
        saliencyTitle: 'Facial Expression Saliency',
        saliencyDescription:
            'Facial movement analysis with hypomimia and expression range markers',
        saliencyLegend:
            'Red = Reduced expression  |  Yellow = Moderate  |  Green = Normal range',
        visualizationType: 'bars',
        summary:
            'Facial analysis evaluates expression range, blink patterns, smile dynamics and hypomimia indicators for PD screening.',
        confidence: 0.65,
        shapValues: [
          SHAPValue(
              name: 'Hypomimia Score',
              value: 0.22,
              level: 'High',
              color: redAccent),
          SHAPValue(
              name: 'Blink Rate',
              value: 0.18,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Smile Velocity',
              value: 0.15,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Expression Range',
              value: 0.12,
              level: 'Medium',
              color: orangeAccent),
          SHAPValue(
              name: 'Facial Symmetry',
              value: 0.08,
              level: 'Low',
              color: greenAccent),
        ],
        featureImportance: [
          FeatureImportance(name: 'Hypomimia Score', value: 0.12),
          FeatureImportance(name: 'Blink Rate', value: 0.12),
          FeatureImportance(name: 'Smile Amplitude', value: 0.10),
          FeatureImportance(name: 'Smile Velocity', value: 0.10),
          FeatureImportance(name: 'Expression Range', value: 0.10),
          FeatureImportance(name: 'Facial Symmetry', value: 0.08),
        ],
        interpretationPoints: [
          InterpretationPoint(
            title: 'Hypomimia Assessment',
            description: 'Facial expression range provides hypomimia assessment for PD screening',
            color: pinkAccent,
          ),
          InterpretationPoint(
            title: 'Blink Pattern',
            description: 'Blink rate below 10/min may indicate facial masking (PD marker)',
            color: orangeAccent,
          ),
          InterpretationPoint(
            title: 'Smile Dynamics',
            description: 'Smile velocity and symmetry reflect facial muscle control',
            color: greenAccent,
          ),
        ],
        limeValues: [
          LIMEValue(name: 'hypomimia_score', weight: 0.24, direction: 'risk',
              description: 'Reduced facial expression strongly increases PD risk', color: redAccent),
          LIMEValue(name: 'blink_rate', weight: 0.18, direction: 'risk',
              description: 'Abnormal blink rate contributes to risk prediction', color: orangeAccent),
          LIMEValue(name: 'smile_velocity', weight: -0.15, direction: 'protective',
              description: 'Fast smile onset reduces predicted risk', color: greenAccent),
          LIMEValue(name: 'expression_range', weight: -0.12, direction: 'protective',
              description: 'Wide expression range is a protective indicator', color: greenAccent),
          LIMEValue(name: 'facial_symmetry', weight: -0.08, direction: 'protective',
              description: 'Symmetric facial movements reduce risk prediction', color: greenAccent),
        ],
        igAttributions: [
          IGAttribution(name: 'hypomimia_score', attribution: 0.28, importance: 0.22,
              direction: 'risk', color: redAccent),
          IGAttribution(name: 'blink_rate', attribution: 0.19, importance: 0.16,
              direction: 'risk', color: orangeAccent),
          IGAttribution(name: 'smile_velocity', attribution: -0.14, importance: 0.13,
              direction: 'protective', color: greenAccent),
          IGAttribution(name: 'smile_amplitude', attribution: -0.10, importance: 0.10,
              direction: 'protective', color: greenAccent),
          IGAttribution(name: 'expression_range', attribution: -0.11, importance: 0.11,
              direction: 'protective', color: greenAccent),
        ],
        counterfactuals: [],
        actionableInsights: [
          ActionableInsight(
            feature: 'Facial Exercises',
            recommendation: 'Practice exaggerated smiling, eyebrow raises, and facial stretches daily',
            priority: 'high',
            benefit: 'Maintains facial muscle tone and expression range',
          ),
          ActionableInsight(
            feature: 'Social Engagement',
            recommendation: 'Maintain active social interactions to keep facial muscles engaged',
            priority: 'medium',
            benefit: 'Natural facial exercise through conversation and expression',
          ),
          ActionableInsight(
            feature: 'Speech Therapy',
            recommendation: 'Consider speech therapy which also works on facial expression',
            priority: 'medium',
            benefit: 'Targets both speech and facial motor control simultaneously',
          ),
        ],
        attentionBars: [
          AttentionBar(
              feature: 'hypomimia_score',
              weight: 0.22,
              importance: 0.18,
              activated: true,
              category: 'facial',
              color: redAccent),
          AttentionBar(
              feature: 'blink_rate',
              weight: 0.18,
              importance: 0.15,
              activated: true,
              category: 'facial',
              color: orangeAccent),
          AttentionBar(
              feature: 'smile_velocity',
              weight: 0.15,
              importance: 0.12,
              activated: true,
              category: 'facial',
              color: orangeAccent),
          AttentionBar(
              feature: 'expression_range',
              weight: 0.12,
              importance: 0.10,
              activated: true,
              category: 'facial',
              color: orangeAccent),
          AttentionBar(
              feature: 'facial_symmetry',
              weight: 0.08,
              importance: 0.06,
              activated: false,
              category: 'facial',
              color: Colors.grey),
        ],
        attentionSummary:
            'Model focuses most on: hypomimia_score, blink_rate, smile_velocity',
        attentionNarrative:
            'For facial assessment, the model\'s attention mechanism focused on expression range and blink patterns. The attention pattern is consistent with PD-related hypomimia biomarkers.',
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
        setState(() => _selectedNavIndex = index);
        break;
      case 3:
        Navigator.pushNamed(context, '/neuro-chat');
        break;
      case 4:
        Navigator.pushNamed(context, '/reports');
        break;
      case 5:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  AnalysisModule get selectedModule => modules[_selectedModuleIndex];

  /// Always show all modules — categories are permanently visible.
  List<int> get _visibleModules {
    return List.generate(modules.length, (i) => i);
  }

  /// Method indices available for the currently selected module.
  List<int> get _visibleMethods {
    final methods = selectedModule.availableMethods;
    // If module has real data, only show methods with data; otherwise show all
    if (selectedModule.hasRealData && methods.isNotEmpty) {
      final sorted = methods.toList()..sort();
      return sorted;
    }
    return List.generate(_xaiMethods.length, (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: ShimmerLoading(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                    SkeletonLine(width: 160, height: 22),
                    SkeletonCircle(size: 40),
                  ]),
                  const SizedBox(height: 8),
                  const SkeletonLine(width: 240, height: 14),
                  const SizedBox(height: 24),
                  // Module tabs
                  Row(children: const [
                    SkeletonBox(width: 90, height: 36, borderRadius: 18),
                    SizedBox(width: 10),
                    SkeletonBox(width: 90, height: 36, borderRadius: 18),
                    SizedBox(width: 10),
                    SkeletonBox(width: 90, height: 36, borderRadius: 18),
                  ]),
                  const SizedBox(height: 24),
                  // Result summary card
                  const SkeletonBox(width: double.infinity, height: 160, borderRadius: 20),
                  const SizedBox(height: 24),
                  // XAI method tabs
                  const SkeletonLine(width: 140, height: 18),
                  const SizedBox(height: 12),
                  Row(children: const [
                    SkeletonBox(width: 70, height: 32, borderRadius: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 70, height: 32, borderRadius: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 70, height: 32, borderRadius: 16),
                    SizedBox(width: 8),
                    SkeletonBox(width: 70, height: 32, borderRadius: 16),
                  ]),
                  const SizedBox(height: 24),
                  // Explanation card
                  const SkeletonBox(width: double.infinity, height: 200, borderRadius: 20),
                  const SizedBox(height: 16),
                  const SkeletonBox(width: double.infinity, height: 140, borderRadius: 16),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
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
                    const SizedBox(height: 16),
                    if (!selectedModule.hasRealData)
                      _buildNoDataPlaceholder()
                    else ...[
                      _buildMethodSelector(),
                      const SizedBox(height: 16),
                      _buildInterpretationGuideCard(),
                      const SizedBox(height: 20),
                      // Dynamic content based on selected XAI method
                      _buildSelectedMethodContent(),
                    ],
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

  // ------------------------------------------------------------------ //
  // No-data placeholder for untested modules                           //
  // ------------------------------------------------------------------ //
  Widget _buildNoDataPlaceholder() {
    final mod = selectedModule;
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: mod.color.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: mod.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(mod.icon, color: mod.color, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                '${mod.name} Analysis',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'No test results yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: mod.color),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete the ${mod.name} test to see AI-powered explanations, feature importance, and personalized insights.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 24),
              // Preview bars at zero
              ...List.generate(4, (i) {
                final labels = ['Feature 1', 'Feature 2', 'Feature 3', 'Feature 4'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(labels[i],
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.black.withValues(alpha: 0.3))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: mod.color.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: mod.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: mod.color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.science_rounded,
                        color: mod.color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Perform test to unlock insights',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mod.color),
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

  // ------------------------------------------------------------------ //
  // Per-module interpretation guide (compact info icon + popup)         //
  // ------------------------------------------------------------------ //
  Widget _buildInterpretationGuideCard() {
    return _buildAnimatedWidget(
      delay: 0.13,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () => _showInterpretationSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selectedModule.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selectedModule.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selectedModule.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info_outline_rounded,
                      size: 16, color: selectedModule.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap to see risk ranges & feature glossary for ${selectedModule.name}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selectedModule.color),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: selectedModule.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInterpretationSheet(BuildContext ctx) {
    final moduleName = selectedModule.name;
    final guidePoints = _getInterpretationGuide(moduleName);
    final glossary = _getFeatureGlossary(moduleName);

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_rounded,
                      size: 20, color: selectedModule.color),
                  const SizedBox(width: 10),
                  Text('$moduleName — Risk Ranges',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: selectedModule.color)),
                ],
              ),
              const SizedBox(height: 14),
              ...guidePoints.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: point['color'] as Color,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: '${point['range']}  ',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: point['color'] as Color),
                              ),
                              TextSpan(
                                text: point['label'] as String,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black.withOpacity(0.6)),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      size: 20, color: selectedModule.color),
                  const SizedBox(width: 10),
                  Text('Feature Glossary',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: selectedModule.color)),
                ],
              ),
              const SizedBox(height: 10),
              ...glossary.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                        ),
                        Expanded(
                          child: Text(e.value,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withOpacity(0.6))),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, String> _getFeatureGlossary(String module) {
    switch (module) {
      case 'Speech':
        return {
          'F0 Mean': 'Fundamental frequency — average voice pitch (Hz). Normal: 85-180 Hz (male), 165-255 Hz (female)',
          'Fundamental Frequency': 'Average voice pitch (Hz). Lower or unstable F0 may indicate neurological changes',
          'F0 Variability': 'Pitch variation across speech. Low variability = monotone, may suggest PD',
          'F0 Std': 'Standard deviation of pitch — higher in emotional/normal speech',
          'Jitter': 'Cycle-to-cycle pitch irregularity. Normal <1%. Higher = voice instability',
          'Voice Jitter': 'Pitch perturbation — rapid involuntary pitch changes. Normal <1%',
          'Shimmer': 'Amplitude variation between cycles. Normal <3%. Higher = breathiness',
          'Voice Shimmer': 'Loudness perturbation — involuntary volume changes. Normal <3%',
          'HNR': 'Harmonics-to-Noise Ratio — voice clarity. Normal >20 dB. Lower = hoarse voice',
          'Harmonics-to-Noise': 'Voice clarity ratio. Higher = cleaner voice. <10 dB is concerning',
          'Pause Rate': 'Number of pauses per minute. Normal: 5-10/min. High = word-finding difficulty',
          'Speech Pauses': 'Frequency of speech interruptions. Excessive pauses linked to cognitive decline',
          'Pause Duration': 'Average length of pauses. Normal <1s. Pauses >2s may indicate word retrieval issues',
          'Mean Pause Duration': 'Average pause length in seconds. Longer pauses suggest cognitive load',
          'Max Pause Duration': 'Longest single pause. Normal <2s. Very long pauses = word-finding difficulty',
          'Speech Rate': 'Words per minute. Normal: 120-180 wpm. Slower may indicate cognitive or motor issues',
          'Vowel Stability': 'How steady a sustained "aah" is held. Low stability = voice tremor (PD marker)',
          'Voice Stability': 'Steadiness of voice output. Instability suggests laryngeal tremor or neurological issue',
          'Story Recall': 'Accuracy of remembered story details (0-1). <0.5 = poor episodic memory',
          'Story Recall Accuracy': 'Fraction of story elements correctly recalled. Low = AD risk marker',
          'Narrative Coherence': 'Logical flow and organization of retold story. Disorganized = frontal dysfunction',
          'Story Coherence': 'How logically connected the recalled narrative is (0-1)',
          'Speech Duration': 'Total time spent speaking. Very short = reduced verbal output',
          'Word Count': 'Total words produced. Low count may reflect reduced fluency',
          'Unique Words': 'Number of different words used. Low diversity = limited vocabulary access',
          'Speech-Silence Ratio': 'Ratio of speaking to silence. Low ratio = excessive pausing',
          'Sustained Vowel Duration': 'How long a vowel was held. Normal >5s. Short = respiratory weakness',
          'Amplitude Variation': 'Variation in voice loudness. High variation = poor motor control',
          'MFCC': 'Mel-frequency cepstral coefficients — encode vocal tract shape. Used by AI model internally',
          'Processing Speed': 'Response time in milliseconds. Slower = reduced cognitive processing',
        };
      case 'Motor':
        return {
          'Spiral Tremor': 'Tremor detected in spiral drawing via point analysis. High = PD indicator',
          'Spiral Tremor Detection': 'AI-detected tremor amplitude in spiral. Score >1.5 is concerning',
          'Spiral Tremor Score': 'Quantified tremor from acceleration changes in spiral drawing',
          'Spiral Deviation': 'How far the drawing deviates from ideal spiral path. >0.8 = imprecise',
          'Spiral Drawing Accuracy': 'Precision of spiral tracing. Lower = more deviation from template',
          'Spiral Drawing Speed': 'Average pen/finger speed while drawing spiral',
          'Spiral Speed Variability': 'Inconsistency in drawing speed. High = jerky movement (PD sign)',
          'Spiral Tightness': 'How tightly wound the spiral loops are. Irregular = motor dysfunction',
          'Meander Tremor': 'Tremor detected in wave/meander tracing. Score >1.5 is concerning',
          'Meander Tremor Detection': 'AI-detected tremor in meander drawing',
          'Meander Tremor Score': 'Quantified tremor from meander drawing acceleration patterns',
          'Meander Deviation': 'Deviation from ideal meander path. >0.8 = imprecise motor control',
          'Meander Drawing Accuracy': 'Precision of meander tracing against template',
          'Meander Smoothness': 'How smooth the meander lines are. Rough = tremor or incoordination',
          'Meander Drawing Speed': 'Average speed while drawing meander pattern',
          'Tremor Score': 'Combined tremor score from drawing point acceleration analysis',
          'Drawing Speed': 'Average drawing speed across tests (pixels/second)',
          'Speed Variability': 'Inconsistency in drawing speed. Normal <1.0, High >2.0',
          'Drawing Detail': 'Number of drawing points captured. More = finer motor detail',
          'Tremor Amplitude': 'Resting tremor from accelerometer (m/s\u00B2). >0.5 = notable tremor',
          'Tapping Rate': 'Finger taps per second. Healthy: 5-7 taps/s. Slow = bradykinesia (PD)',
          'Tapping Speed': 'Speed of repetitive finger tapping. Slower = motor slowing',
          'Tapping Regularity': 'Consistency of tap intervals (0-1). Low = irregular rhythm (PD sign)',
          'Tapping Fatigue': 'Speed drop-off during sustained tapping. High = motor fatigue (PD sign)',
          'Motor Fatigue': 'Decline in motor performance over time. Higher index = more fatigue',
          'Motor Composite': 'Combined motor function score across all motor tests',
          'Line Smoothness': 'How smooth the drawn lines are. Rough = micro-tremor or incoordination',
          'Drawing Duration': 'Time taken to complete drawing. Very slow = motor impairment',
        };
      case 'Cognitive':
        return {
          'TMT-A Time': 'Trail Making A — connect numbers 1-25. Normal <30s (young), <60s (elderly)',
          'TMT-B Time': 'Trail Making B — alternate numbers/letters. Normal <60s (young), <120s (elderly)',
          'TMT B/A Ratio': 'TMT-B divided by TMT-A. Normal: 2-3. >3.5 = executive dysfunction',
          'B/A Ratio': 'Ratio of TMT-B to TMT-A time. Higher = worse cognitive flexibility',
          'TMT-A Errors': 'Mistakes in Part A sequence. Normal: 0-1',
          'TMT-B Errors': 'Mistakes in Part B sequence. >3 errors = attention/executive issues',
          'TMT-B Sequence Errors': 'Wrong-order connections in Part B. Indicates set-shifting difficulty',
          'Stroop Accuracy': 'Color-word interference test accuracy. Normal >85%. Low = attention deficit',
          'Stroop Test Accuracy': 'Percentage of correct responses on Stroop color naming',
          'Stroop Interference': 'Difficulty ignoring conflicting color-word info. High = executive dysfunction',
          'Stroop Response Time': 'Average reaction time on Stroop test (ms). Slower = processing delay',
          'Stroop Error Rate': 'Percentage of wrong answers on Stroop. High = impaired inhibition',
          'N-Back Accuracy': 'Working memory test accuracy. Normal >70%. Low = memory buffer issues',
          'N-Back Level': 'Highest N-Back level achieved. Higher = better working memory capacity',
          'Signal Detection': 'D-prime score — ability to distinguish targets from distractors',
          'Recall Accuracy': 'Story/word recall score (0-1). <0.5 = poor episodic memory (AD marker)',
          'Word Recall Accuracy': 'Fraction of presented words correctly recalled',
          'Recall Intrusions': 'False memories — words recalled that were never presented. >2 = concerning',
          'Clock Drawing Score': 'Shulman CDT score (0-5). 0=perfect clock, 3+=visuospatial impairment',
          'Shulman Score': 'Clock Drawing Test Shulman scale. 0-1=normal, 3-5=impaired',
          'Number Accuracy': 'How accurately clock numbers are placed (0-1)',
          'Clock Contour': 'Quality of the drawn clock circle. <50 = spatial planning issues',
          'Path Efficiency': 'Directness of TMT drawing path (0-1). Low = planning difficulty',
          'Spatial Accuracy': 'Precision of target connections in TMT',
          'Pen Velocity': 'Average drawing speed in TMT. Very slow = motor or cognitive slowing',
          'Movement Jerk': 'Smoothness of pen movement. High jerk = tremor or incoordination',
          'Pen Pauses': 'Number of hesitations while drawing. Many = planning difficulty',
          'Pen Lifts': 'Times the pen was lifted during TMT. Many = uncertainty or confusion',
          'Cognitive Composite': 'Combined score across all cognitive tests',
        };
      case 'Facial':
        return {
          'Blink Rate': 'Blinks per minute. Normal: 15-20/min. <10 = possible hypomimia (PD). >25 = stress/dry eyes',
          'Blink Count': 'Total blinks during observation period. Low count suggests reduced spontaneous movement',
          'Avg Blink Duration': 'Average duration of each blink in ms. Normal: 150-300ms',
          'Smile Velocity': 'Speed of smile onset. Slower = possible facial bradykinesia (PD). Normal: 0.5-1.0',
          'Smile Symmetry': 'Left-right symmetry during smile. <80% may indicate unilateral facial weakness',
          'Smile Amplitude': 'Maximum mouth opening during smile. Reduced = hypomimia. Normal: 0.7-1.0',
          'Smile Intensity': 'Overall smile strength. Low intensity suggests reduced facial expression',
          'Expression Intensity': 'Overall smile strength. Low intensity suggests reduced facial expression',
          'Smile Count': 'Number of voluntary smiles. Zero = possible facial masking',
          'Facial Symmetry': 'Overall face symmetry at rest. <80% suggests asymmetric muscle tone',
          'Muscle Tone': 'Facial muscle tone at rest. Low = hypotonia, rigid = possible PD rigidity',
          'Expression Range': 'Range of facial expressions achieved. <50% = reduced expressivity (PD marker)',
          'Hypomimia Score': 'Facial masking score. Higher = more masking. >70 = significant PD indicator',
          'Facial Expressivity': 'Combined expressivity score (0-100). Lower = more PD-like facial masking',
          'Symmetry Composite': 'Average of resting and dynamic facial symmetry',
          'AU01 Inner Brow Raise': 'Action Unit 01 — inner eyebrow raise. Reduced = less expression',
          'AU06 Cheek Raiser': 'Action Unit 06 — cheek raising during smile. Key PD hypomimia marker',
          'AU12 Lip Corner Puller': 'Action Unit 12 — smile muscle. Most important AU for PD detection',
          'AU25 Lips Part': 'Action Unit 25 — lips parting. Reduced in PD facial masking',
          'AU45 Blink': 'Action Unit 45 — blink frequency and intensity',
          'Mouth Opening': 'Average mouth opening during expressions. Reduced = hypomimia',
          'Mouth Width': 'Mouth width during smile. Narrower = reduced expression',
          'Jaw Opening': 'Jaw range of motion during expressions',
          'Eye Opening': 'Eye aperture. Reduced blinking + narrower eyes = PD indicator',
          'Eye Raise': 'Eyebrow raise capability. Reduced = facial masking',
          'Combined Facial Score': 'Overall facial analysis score combining all metrics',
        };
      default:
        return {};
    }
  }

  List<Map<String, dynamic>> _getInterpretationGuide(String module) {
    switch (module) {
      case 'Speech':
        return [
          {'range': 'AD Risk < 20%', 'label': 'Normal speech patterns — no concerns', 'color': greenAccent},
          {'range': '20% - 35%', 'label': 'Mild changes — monitor over time', 'color': yellowAccent},
          {'range': '35% - 55%', 'label': 'Notable changes — consider professional evaluation', 'color': orangeAccent},
          {'range': '> 55%', 'label': 'Significant markers — consult a neurologist', 'color': redAccent},
        ];
      case 'Motor':
        return [
          {'range': 'PD Risk < 20%', 'label': 'Normal motor function — no tremor detected', 'color': greenAccent},
          {'range': '20% - 35%', 'label': 'Mild irregularities — may be phone artifacts', 'color': yellowAccent},
          {'range': '35% - 55%', 'label': 'Motor signs present — movement evaluation advised', 'color': orangeAccent},
          {'range': '> 55%', 'label': 'Strong motor markers — consult a movement specialist', 'color': redAccent},
        ];
      case 'Cognitive':
        return [
          {'range': 'AD Risk < 20%', 'label': 'Normal cognition — healthy performance', 'color': greenAccent},
          {'range': '20% - 35%', 'label': 'Subjective decline — within age norms, monitor', 'color': yellowAccent},
          {'range': '35% - 55%', 'label': 'Mild Cognitive Impairment (MCI) range — seek evaluation', 'color': orangeAccent},
          {'range': '> 55%', 'label': 'Significant impairment — neuropsychological testing recommended', 'color': redAccent},
        ];
      case 'Facial':
        return [
          {'range': 'PD Risk < 20%', 'label': 'Normal facial expressions — no hypomimia', 'color': greenAccent},
          {'range': '20% - 35%', 'label': 'Mild reduction in expressivity — monitor', 'color': yellowAccent},
          {'range': '35% - 55%', 'label': 'Notable facial masking — evaluation advised', 'color': orangeAccent},
          {'range': '> 55%', 'label': 'Significant hypomimia — consult a neurologist', 'color': redAccent},
        ];
      default:
        return [];
    }
  }

  // ------------------------------------------------------------------ //
  // Per-method, per-category guidance text                              //
  // ------------------------------------------------------------------ //
  Widget _buildMethodGuidanceBox(String guidance) {
    if (guidance.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selectedModule.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selectedModule.color.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded,
                size: 16, color: selectedModule.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(guidance,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.6),
                      height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  String _getMethodGuidance(String module, int methodIndex) {
    // methodIndex: 0=SHAP, 1=GradCAM, 2=LIME, 3=IG, 4=What-If, 5=Attention, 6=Clinical
    final key = '${module}_$methodIndex';
    const guides = {
      // Speech SHAP
      'Speech_0': 'SHAP bars show how much each speech feature pushed the risk score up or down. Higher bars = stronger influence. "High" means this feature is a key driver of your result.',
      // Speech GradCAM
      'Speech_1': 'The saliency map highlights audio regions the AI focused on. Red zones indicate abnormal pauses (>2s) often linked to word-finding difficulty. Green = normal speech flow.',
      // Speech LIME
      'Speech_2': 'LIME shows which speech features locally affected your prediction. Green (protective) features like good recall accuracy or stable voice reduce risk. Red features like high pause rate increase it.',
      // Speech IG
      'Speech_3': 'Integrated Gradients traces the path from a "blank" baseline to your actual speech input. Features with high attribution had the biggest cumulative effect on the prediction.',
      // Speech What-If
      'Speech_4': 'What-If scenarios show how changing specific speech metrics could reduce your risk. "Modifiable" items (like speech rate) can be improved through practice.',
      // Speech Attention
      'Speech_5': 'Attention weights show which speech features the neural network weighted most heavily. Activated features (orange) are the primary drivers of the final prediction.',
      // Speech Clinical
      'Speech_6': 'Clinical interpretation maps AI outputs to established neuropsychological standards. Pause patterns, fluency, and voice quality are compared against age-normative reference ranges.',

      // Motor SHAP
      'Motor_0': 'SHAP bars show which motor features most influenced the PD risk score. Tremor amplitude and drawing deviation are typically the strongest signals. Phone drawings may show lower tremor than paper.',
      // Motor GradCAM
      'Motor_1': 'The saliency map highlights drawing regions with detected irregularities. Red dots = high tremor zones, yellow = moderate deviation. Phone finger drawings naturally look smoother than pen strokes.',
      // Motor LIME
      'Motor_2': 'LIME shows local feature effects on motor prediction. spiral_tremor and meander_tremor reflect drawing-point analysis, not raw phone smoothness. Tapping regularity is a reliable PD indicator.',
      // Motor IG
      'Motor_3': 'Integrated Gradients shows the cumulative impact of each motor feature. Spiral and meander tremor features have the highest attribution because they directly capture PD-related micro-tremor patterns.',
      // Motor What-If
      'Motor_4': 'What-If scenarios model how improving motor metrics could lower PD risk. Tapping speed and fatigue are partially modifiable through exercise. Tremor amplitude is diagnostic (not directly modifiable).',
      // Motor Attention
      'Motor_5': 'Attention patterns reveal which motor biomarkers the model prioritized. For PD detection, the model typically attends most to tremor frequency, amplitude, and regularity of repetitive movements.',
      // Motor Clinical
      'Motor_6': 'Clinical interpretation compares your motor results against established PD screening thresholds. Drawing precision and tapping rhythm are mapped to UPDRS-equivalent scales.',

      // Cognitive SHAP
      'Cognitive_0': 'SHAP bars show the contribution of each cognitive test to AD risk. TMT-B time and recall accuracy are usually the top contributors. CDT (Clock Drawing) score reflects visuospatial ability.',
      // Cognitive GradCAM
      'Cognitive_1': 'The cognitive saliency map visualizes performance across test domains. Low bars indicate delayed or impaired responses. Red paths mark errors in Trail Making Test sequences.',
      // Cognitive LIME
      'Cognitive_2': 'LIME reveals local effects per cognitive feature. High recall_accuracy and good stroop_accuracy are protective (green). Slow TMT-B time and high error counts increase risk (red).',
      // Cognitive IG
      'Cognitive_3': 'Integrated Gradients traces how each cognitive metric built up the final prediction from zero. TMT completion time and recall accuracy typically show the steepest attribution gradients.',
      // Cognitive What-If
      'Cognitive_4': 'What-If analysis shows which cognitive improvements would most reduce AD risk. Word recall is partially modifiable through memory training. TMT-B time is a diagnostic indicator, not directly changeable.',
      // Cognitive Attention
      'Cognitive_5': 'Attention visualization shows which cognitive domains the model weighted most. Executive function (TMT) and memory (recall) typically receive the highest attention weights for AD prediction.',
      // Cognitive Clinical
      'Cognitive_6': 'Clinical interpretation maps your cognitive results to standard neuropsychological categories. TMT-B, Stroop, N-Back, CDT and Story Recall are compared to age and education-adjusted norms.',

      // Facial SHAP
      'Facial_0': 'SHAP bars show which facial features most influenced the PD risk score. Hypomimia score and blink rate are typically the strongest signals. Reduced expression range is a key PD indicator.',
      // Facial GradCAM
      'Facial_1': 'The facial saliency map highlights expression regions the AI focused on. Red = areas of reduced movement (masking). Green = normal expression range.',
      // Facial LIME
      'Facial_2': 'LIME shows local feature effects on facial PD prediction. Low smile velocity and high hypomimia score increase risk. Good expression range and normal blink rate are protective.',
      // Facial IG
      'Facial_3': 'Integrated Gradients traces how each facial metric built up the prediction. Hypomimia score and AU12 (lip corner puller) typically show the steepest attribution for PD detection.',
      // Facial What-If
      'Facial_4': 'What-If scenarios show how improving facial expression metrics could lower PD risk. Expression range can be improved through facial exercises. Blink rate is partially modifiable.',
      // Facial Attention
      'Facial_5': 'Attention weights reveal which facial biomarkers the model prioritized. For PD, the model attends most to Action Units related to smiling (AU12, AU06) and blink patterns (AU45).',
      // Facial Clinical
      'Facial_6': 'Clinical interpretation maps facial expression results to established hypomimia screening criteria. Blink rate, smile dynamics, and expression range are compared against normative values.',
    };
    return guides[key] ?? '';
  }

  // ------------------------------------------------------------------ //
  // Dynamic content for selected XAI method                             //
  // ------------------------------------------------------------------ //
  Widget _buildSelectedMethodContent() {
    switch (_selectedMethodIndex) {
      case 0:
        return Column(children: [
          _buildSHAPValuesCard(),
          const SizedBox(height: 20),
          _buildFeatureImportanceCard(),
        ]);
      case 1:
        return _buildSaliencyMapCard();
      case 2:
        return _buildLIMECard();
      case 3:
        return _buildIntegratedGradientsCard();
      case 4:
        return _buildCounterfactualCard();
      case 5:
        return _buildAttentionCard();
      case 6:
        return _buildClinicalInterpretationCard();
      default:
        return _buildSHAPValuesCard();
    }
  }

  // ------------------------------------------------------------------ //
  // Header                                                              //
  // ------------------------------------------------------------------ //
  Widget _buildHeader() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Explainable AI',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('7 methods to understand AI predictions',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5))),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: darkCard, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // Transparency Card                                                   //
  // ------------------------------------------------------------------ //
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
                  selectedModule.bgColor.withOpacity(0.5)
                ]),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selectedModule.color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: selectedModule.color.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
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
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.verified_user_rounded,
                    color: selectedModule.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transparency & Trust',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text(
                      'NeuroVerse uses 7 XAI methods: SHAP, GradCAM/Saliency, LIME, Integrated Gradients, Counterfactual Analysis, Attention Visualization, and Clinical Interpretation to explain every prediction.',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5),
                          height: 1.4),
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

  // ------------------------------------------------------------------ //
  // Module Selector (Speech / Motor / Cognitive)                        //
  // ------------------------------------------------------------------ //
  Widget _buildModuleSelector() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Select Analysis Module',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.5))),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _visibleModules.length,
              itemBuilder: (context, listIdx) {
                final index = _visibleModules[listIdx];
                final module = modules[index];
                final isSelected = _selectedModuleIndex == index;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedModuleIndex = index;
                      _autoSelectMethod();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 90,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                  module.color,
                                  module.color.withOpacity(0.8)
                                ])
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: isSelected
                              ? module.color
                              : Colors.black.withOpacity(0.08),
                          width: isSelected ? 2 : 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: module.color.withOpacity(0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6))
                            ]
                          : [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.25)
                                        : module.hasRealData
                                            ? module.bgColor
                                            : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(module.icon,
                                    color: isSelected
                                        ? Colors.white
                                        : module.hasRealData
                                            ? module.color
                                            : Colors.grey.shade400,
                                    size: 20),
                              ),
                              const SizedBox(height: 8),
                              Text(module.name,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : module.hasRealData
                                              ? Colors.black.withOpacity(0.6)
                                              : Colors.black.withOpacity(0.35))),
                            ],
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

  // ------------------------------------------------------------------ //
  // XAI Method Selector (7 methods)                                     //
  // ------------------------------------------------------------------ //
  Widget _buildMethodSelector() {
    return _buildAnimatedWidget(
      delay: 0.12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('XAI Method',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.5))),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _visibleMethods.length,
              itemBuilder: (context, listIdx) {
                final index = _visibleMethods[listIdx];
                final method = _xaiMethods[index];
                final isSelected = _selectedMethodIndex == index;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedMethodIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? method.color : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: isSelected
                              ? method.color
                              : Colors.black.withOpacity(0.08)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: method.color.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(method.icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : Colors.black54),
                        const SizedBox(width: 6),
                        Text(
                          method.name.replaceAll('\n', ' '),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black54),
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

  // ------------------------------------------------------------------ //
  // 1. Saliency / GradCAM Card                                         //
  // ------------------------------------------------------------------ //
  Widget _buildSaliencyMapCard() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                  selectedModule.saliencyTitle, Icons.gradient_rounded,
                  subtitle: 'GradCAM / Saliency visualization'),
              const SizedBox(height: 10),
              _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 1)),
              Text(selectedModule.saliencyDescription,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.5))),
              const SizedBox(height: 16),
              _buildVisualization(selectedModule),
              const SizedBox(height: 12),
              _buildLegendBar(
                  selectedModule.saliencyLegend, selectedModule.color),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // 2. SHAP Values Card                                                 //
  // ------------------------------------------------------------------ //
  Widget _buildSHAPValuesCard() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                  'SHAP Values', Icons.bar_chart_rounded,
                  subtitle: 'Feature contribution to risk prediction'),
              const SizedBox(height: 12),
              _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 0)),
              ...selectedModule.shapValues
                  .map((shap) => _buildHorizontalBar(
                        label: shap.name,
                        value: shap.value,
                        maxValue: 0.30,
                        color: shap.color,
                        badge: shap.level,
                      ))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // 3. LIME Card                                                        //
  // ------------------------------------------------------------------ //
  Widget _buildLIMECard() {
    final limeVals = selectedModule.limeValues;
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                  'LIME Analysis', Icons.science_rounded,
                  subtitle: 'Local Interpretable Model-agnostic Explanations'),
              const SizedBox(height: 10),
              _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 2)),
              Text(
                'How small perturbations in each feature locally affect the prediction:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
              if (limeVals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: orangeAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'LIME analysis is not available for this module. Complete a test to generate local explanations.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: Colors.black.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...limeVals
                    .map((l) => _buildDirectionalBar(
                          label: l.name.replaceAll('_', ' '),
                          value: l.weight,
                          maxValue: 0.30,
                          direction: l.direction,
                          description: l.description,
                        ))
                    .toList(),
              const SizedBox(height: 12),
              _buildLegendBar(
                  'Green = Protective (reduces risk)  |  Red = Risk (increases risk)',
                  greenAccent),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // 4. Integrated Gradients Card                                        //
  // ------------------------------------------------------------------ //
  Widget _buildIntegratedGradientsCard() {
    final igVals = selectedModule.igAttributions;
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                  'Integrated Gradients', Icons.timeline_rounded,
                  subtitle: 'Path-integrated feature attributions'),
              const SizedBox(height: 10),
              _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 3)),
              Text(
                'Attribution scores from baseline (zero) to actual input via gradient integration:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
              if (igVals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: orangeAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Integrated Gradients analysis is not available for this module. Complete a test to generate attributions.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: Colors.black.withValues(alpha: 0.5)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...igVals
                    .map((ig) => _buildDirectionalBar(
                          label: ig.name.replaceAll('_', ' '),
                          value: ig.attribution,
                          maxValue: 0.35,
                          direction: ig.direction,
                          description:
                              'Importance: ${(ig.importance * 100).toStringAsFixed(1)}%',
                        ))
                    .toList(),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: orangeAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: orangeAccent.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: orangeAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Integrated Gradients satisfy completeness axiom: attributions sum to the prediction difference.',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.6)),
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

  // ------------------------------------------------------------------ //
  // 5. Counterfactual / What-If Card                                    //
  // ------------------------------------------------------------------ //
  Widget _buildCounterfactualCard() {
    final cfs = selectedModule.counterfactuals;
    final actions = selectedModule.actionableInsights;
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Counterfactual scenarios
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(
                      'What-If Analysis', Icons.compare_arrows_rounded,
                      subtitle:
                          'Changes that would reduce your risk score'),
                  const SizedBox(height: 10),
                  _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 4)),
                  if (cfs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: greenAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your risk scores are already low. No counterfactual changes needed.',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black.withOpacity(0.6)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...cfs.map((cf) => _buildCounterfactualRow(cf)).toList(),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              // Actionable insights (light theme)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCardHeader('Actionable Recommendations',
                        Icons.tips_and_updates_rounded,
                        subtitle: 'Steps you can take to improve your scores'),
                    const SizedBox(height: 14),
                    ...actions
                        .map((a) => _buildActionableRow(a))
                        .toList(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // 6. Attention Visualization Card                                     //
  // ------------------------------------------------------------------ //
  Widget _buildAttentionCard() {
    final bars = selectedModule.attentionBars;
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader('Attention Patterns',
                  Icons.center_focus_strong_rounded,
                  subtitle: 'What the AI model focused on most'),
              const SizedBox(height: 10),
              _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 5)),
              // Attention bars
              ...bars.map((b) => _buildAttentionBarRow(b)).toList(),
              const SizedBox(height: 16),
              // Summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        pinkAccent.withOpacity(0.08),
                        softLavender.withOpacity(0.3)
                      ]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pinkAccent.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            size: 16, color: pinkAccent),
                        const SizedBox(width: 8),
                        Text('Attention Summary',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.7))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedModule.attentionNarrative.isNotEmpty
                          ? selectedModule.attentionNarrative
                          : selectedModule.attentionSummary,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.6),
                          height: 1.4),
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

  // ------------------------------------------------------------------ //
  // 7. Clinical Interpretation Card                                     //
  // ------------------------------------------------------------------ //
  Widget _buildClinicalInterpretationCard() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardHeader(
                  'Clinical Interpretation', Icons.medical_information_rounded,
                  subtitle: 'Based on neuropsychological assessment standards'),
              const SizedBox(height: 12),
              _buildMethodGuidanceBox(_getMethodGuidance(selectedModule.name, 6)),
              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selectedModule.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.summarize_rounded,
                        color: selectedModule.color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(selectedModule.summary,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.7),
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Confidence meter
              Row(
                children: [
                  Text('Model Confidence:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.5))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: selectedModule.confidence,
                        child: Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                greenAccent,
                                selectedModule.confidence > 0.7
                                    ? greenAccent
                                    : yellowAccent
                              ]),
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      '${(selectedModule.confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.8))),
                ],
              ),
              const SizedBox(height: 16),
              // Interpretation points
              ...selectedModule.interpretationPoints
                  .map((point) => _buildInterpretationRow(point))
                  .toList(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // Feature Importance Card                                             //
  // ------------------------------------------------------------------ //
  Widget _buildFeatureImportanceCard() {
    final features = selectedModule.featureImportance;
    if (features.isEmpty) return const SizedBox.shrink();
    final maxVal = features.map((f) => f.value).reduce((a, b) => a > b ? a : b);

    return _buildAnimatedWidget(
      delay: 0.25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overall Feature Importance',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              const SizedBox(height: 4),
              Text('Ranking of biomarkers by prediction impact',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.5))),
              const SizedBox(height: 16),
              // Horizontal bars (no overflow)
              ...features.map((feature) {
                final ratio = maxVal > 0 ? (feature.value / maxVal).clamp(0.0, 1.0) : 0.0;
                final barColor = ratio > 0.7
                    ? redAccent
                    : ratio > 0.4
                        ? orangeAccent
                        : greenAccent;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(feature.name,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.7)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(7)),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  barColor.withOpacity(0.7),
                                  barColor,
                                ]),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(feature.value.toStringAsFixed(2),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: barColor)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================== //
  // Shared widget builders                                              //
  // ================================================================== //

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black.withOpacity(0.06)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6))
      ],
    );
  }

  Widget _buildCardHeader(String title, IconData icon,
      {String subtitle = ''}) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: selectedModule.bgColor,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: selectedModule.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendBar(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [Colors.red, Colors.yellow]),
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.6))),
          ),
        ],
      ),
    );
  }

  /// Show feature info tooltip when tapping a feature name
  void _showFeatureInfo(String featureName) {
    final glossary = _getFeatureGlossary(selectedModule.name);
    // Word-overlap matching: score each glossary entry by shared words
    final cleanName = featureName.replaceAll('_', ' ').toLowerCase().trim();
    final nameWords = cleanName.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();

    String? info;
    int bestScore = 0;
    for (final entry in glossary.entries) {
      final keyLower = entry.key.toLowerCase();
      final keyWords = keyLower.split(RegExp(r'[\s(/]+'))
          .where((w) => w.length > 1)
          .toSet();
      // Exact match
      if (keyLower == cleanName || cleanName == keyLower) {
        info = entry.value;
        break;
      }
      // Word overlap score
      final overlap = nameWords.intersection(keyWords).length;
      // Also check if one contains the other
      final containsBonus =
          (keyLower.contains(cleanName) || cleanName.contains(keyLower)) ? 2 : 0;
      final score = overlap + containsBonus;
      if (score > bestScore) {
        bestScore = score;
        info = entry.value;
      }
    }
    if (info == null || bestScore == 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(featureName,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selectedModule.color)),
        content: Text(info!,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.7),
                height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got it',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selectedModule.color)),
          ),
        ],
      ),
    );
  }

  /// Horizontal bar for SHAP-style values with risk-level colors
  Widget _buildHorizontalBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    String badge = '',
  }) {
    // Dynamic color by risk level
    final barColor = badge == 'High'
        ? redAccent
        : badge == 'Medium'
            ? orangeAccent
            : greenAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFeatureInfo(label),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline_rounded,
                          size: 12,
                          color: Colors.black.withOpacity(0.3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (badge.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: barColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: barColor)),
                ),
              const SizedBox(width: 6),
              Text(value.toStringAsFixed(2),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: barColor)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ratio = (value / maxValue).clamp(0.0, 1.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: constraints.maxWidth * ratio,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [barColor.withOpacity(0.7), barColor]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Directional bar (LIME / IG) with risk/protective color coding
  Widget _buildDirectionalBar({
    required String label,
    required double value,
    required double maxValue,
    required String direction,
    String description = '',
  }) {
    final color = direction == 'risk' ? redAccent : greenAccent;
    final icon = direction == 'risk'
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showFeatureInfo(label),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.info_outline_rounded,
                          size: 11,
                          color: Colors.black.withOpacity(0.3)),
                    ],
                  ),
                ),
              ),
              Text(value.toStringAsFixed(3),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(3)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ratio = (value / maxValue).clamp(0.0, 1.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: constraints.maxWidth * ratio,
                  height: 6,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3)),
                );
              },
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(description,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.45))),
            ),
        ],
      ),
    );
  }

  /// Counterfactual scenario row
  Widget _buildCounterfactualRow(CounterfactualScenario cf) {
    final isIncrease = cf.changeDirection == 'increase';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tealAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tealAccent.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: tealAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                      isIncrease
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: tealAccent,
                      size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cf.feature,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('-${cf.riskReduction.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: greenAccent)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Before → After
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withOpacity(0.4))),
                      Text(cf.currentValue.toStringAsFixed(
                          cf.currentValue > 10 ? 0 : 2),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: tealAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withOpacity(0.4))),
                      Text(
                          cf.targetValue
                              .toStringAsFixed(cf.targetValue > 10 ? 0 : 2),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: greenAccent)),
                    ],
                  ),
                ),
              ],
            ),
            if (cf.feasibility != 'not_modifiable') ...[
              const SizedBox(height: 6),
              Text(cf.description,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.5))),
            ],
            if (cf.feasibility == 'not_modifiable') ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Diagnostic indicator (not directly modifiable)',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.4))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Actionable insight row (light theme)
  Widget _buildActionableRow(ActionableInsight action) {
    final accentColor = action.priority == 'high' ? orangeAccent : tealAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                action.priority == 'high'
                    ? Icons.priority_high_rounded
                    : Icons.lightbulb_outline_rounded,
                size: 16,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(action.feature,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor)),
                      ),
                      if (action.benefit.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: greenAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(action.benefit,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: greenAccent)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(action.recommendation,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.6),
                          height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Attention bar row
  Widget _buildAttentionBarRow(AttentionBar bar) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bar.activated ? orangeAccent : Colors.grey.shade300,
              boxShadow: bar.activated
                  ? [
                      BoxShadow(
                          color: orangeAccent.withOpacity(0.5),
                          blurRadius: 4)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(bar.feature.replaceAll('_', ' '),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.7)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(5)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = (bar.weight / 0.40).clamp(0.0, 1.0);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: constraints.maxWidth * ratio,
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        bar.activated
                            ? orangeAccent.withOpacity(0.7)
                            : Colors.grey.shade300,
                        bar.activated ? orangeAccent : Colors.grey.shade400,
                      ]),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(bar.weight * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: bar.activated
                      ? orangeAccent
                      : Colors.black.withOpacity(0.4))),
        ],
      ),
    );
  }

  /// Clinical interpretation row (light theme)
  Widget _buildInterpretationRow(InterpretationPoint point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: point.color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: point.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: point.color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                          color: point.color.withOpacity(0.5), blurRadius: 4)
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(point.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: point.color)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: point.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(point.severity.toUpperCase(),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: point.color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(point.description,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.6),
                    height: 1.3)),
            if (point.recommendation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: Colors.black.withOpacity(0.35)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(point.recommendation,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.black.withOpacity(0.45),
                            fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ //
  // Visualizations                                                      //
  // ------------------------------------------------------------------ //
  Widget _buildVisualization(AnalysisModule module) {
    switch (module.visualizationType) {
      case 'spectrogram':
        return _buildSpectrogramVisualization();
      case 'spiral':
        return _buildSpiralVisualization();
      case 'bars':
        return _buildBarsVisualization();
      default:
        return _buildBarsVisualization();
    }
  }

  Widget _buildSpectrogramVisualization() {
    // Speech is tabular — show feature saliency bars from real SHAP data
    final features = selectedModule.shapValues;
    if (features.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: blueAccent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('No saliency data available for speech',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.4))),
        ),
      );
    }
    final maxVal = features.map((f) => f.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFEFF6FF),
              blueAccent.withOpacity(0.08),
            ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blueAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Speech Feature Saliency',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: blueAccent)),
          const SizedBox(height: 10),
          ...features.map((f) {
            final ratio = maxVal > 0 ? (f.value / maxVal).clamp(0.0, 1.0) : 0.0;
            final barColor = f.level == 'High'
                ? redAccent
                : f.level == 'Medium'
                    ? orangeAccent
                    : greenAccent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 75,
                    child: Text(f.name,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.6)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(5)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [barColor.withOpacity(0.6), barColor]),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                        color: barColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(f.level,
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: barColor)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
            size: const Size(120, 120), painter: ImprovedSpiralPainter()),
      ),
    );
  }

  Widget _buildBarsVisualization() {
    // Use real feature importance data for cognitive saliency
    final features = selectedModule.featureImportance.take(6).toList();
    if (features.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: purpleAccent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('No saliency data available',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.4))),
        ),
      );
    }
    final maxVal = features.map((f) => f.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [softLavender.withOpacity(0.3), Colors.white]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cognitive Feature Saliency',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: purpleAccent)),
          const SizedBox(height: 10),
          ...features.map((f) {
            final ratio = maxVal > 0
                ? (f.value / maxVal).clamp(0.0, 1.0)
                : 0.0;
            final barColor = ratio > 0.7
                ? redAccent
                : ratio > 0.4
                    ? orangeAccent
                    : greenAccent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(f.name,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.6)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(5)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [barColor.withOpacity(0.6), barColor]),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(f.value.toStringAsFixed(2),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: barColor)),
                ],
              ),
            );
          }),
        ],
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
              offset: const Offset(0, 4))
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
              _buildNavItem(2, Icons.auto_awesome_rounded, 'XAI'),
              _buildNavItem(3, Icons.stars_rounded, 'Neuro'),
              _buildNavItem(4, Icons.description_outlined, 'Reports'),
              _buildNavItem(5, Icons.person_outline_rounded, 'Profile'),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: isSelected ? darkCard : Colors.transparent,
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.black38, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
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
        curve:
            Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(
          parent: _pageController,
          curve: Interval(delay, math.min(delay + 0.3, 1.0),
              curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}

// ================================================================== //
// Data Models                                                         //
// ================================================================== //

class _XAIMethod {
  final String name;
  final IconData icon;
  final Color color;
  const _XAIMethod(this.name, this.icon, this.color);
}

class AnalysisModule {
  final String name;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String saliencyTitle;
  final String saliencyDescription;
  final String saliencyLegend;
  final String visualizationType;
  String summary;
  double confidence;

  List<SHAPValue> shapValues;
  List<FeatureImportance> featureImportance;
  List<InterpretationPoint> interpretationPoints;
  List<LIMEValue> limeValues;
  List<IGAttribution> igAttributions;
  List<CounterfactualScenario> counterfactuals;
  List<ActionableInsight> actionableInsights;
  List<AttentionBar> attentionBars;
  String attentionSummary;
  String attentionNarrative;

  /// Whether this module has real data from the backend (not just defaults).
  bool hasRealData;

  /// Which XAI method indices (0-6) have real data for this module.
  /// 0=SHAP, 1=GradCAM, 2=LIME, 3=IG, 4=What-If, 5=Attention, 6=Clinical
  Set<int> availableMethods;

  AnalysisModule({
    required this.name,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.saliencyTitle,
    required this.saliencyDescription,
    required this.saliencyLegend,
    required this.visualizationType,
    this.summary = '',
    this.confidence = 0.5,
    required this.shapValues,
    required this.featureImportance,
    required this.interpretationPoints,
    this.limeValues = const [],
    this.igAttributions = const [],
    this.counterfactuals = const [],
    this.actionableInsights = const [],
    this.attentionBars = const [],
    this.attentionSummary = '',
    this.attentionNarrative = '',
    this.hasRealData = false,
    Set<int>? availableMethods,
  }) : availableMethods = availableMethods ?? {0, 1, 2, 3, 4, 5, 6};
}

class SHAPValue {
  final String name;
  final double value;
  final String level;
  final Color color;
  SHAPValue(
      {required this.name,
      required this.value,
      required this.level,
      required this.color});
}

class FeatureImportance {
  final String name;
  final double value;
  FeatureImportance({required this.name, required this.value});
}

class InterpretationPoint {
  final String title;
  final String description;
  final String recommendation;
  final String severity;
  final Color color;
  InterpretationPoint({
    required this.title,
    required this.description,
    this.recommendation = '',
    this.severity = 'info',
    required this.color,
  });
}

class LIMEValue {
  final String name;
  final double weight;
  final String direction;
  final String description;
  final Color color;
  LIMEValue({
    required this.name,
    required this.weight,
    required this.direction,
    required this.description,
    required this.color,
  });
}

class IGAttribution {
  final String name;
  final double attribution;
  final double importance;
  final String direction;
  final Color color;
  IGAttribution({
    required this.name,
    required this.attribution,
    required this.importance,
    required this.direction,
    required this.color,
  });
}

class CounterfactualScenario {
  final String feature;
  final double currentValue;
  final double targetValue;
  final String changeDirection;
  final double riskReduction;
  final String description;
  final String feasibility;
  CounterfactualScenario({
    required this.feature,
    required this.currentValue,
    required this.targetValue,
    required this.changeDirection,
    required this.riskReduction,
    required this.description,
    this.feasibility = 'unknown',
  });
}

class ActionableInsight {
  final String feature;
  final String recommendation;
  final String priority;
  final String benefit;
  ActionableInsight({
    required this.feature,
    required this.recommendation,
    this.priority = 'medium',
    this.benefit = '',
  });
}

class AttentionBar {
  final String feature;
  final double weight;
  final double importance;
  final bool activated;
  final String category;
  final Color color;
  AttentionBar({
    required this.feature,
    required this.weight,
    required this.importance,
    required this.activated,
    required this.category,
    required this.color,
  });
}

// ================================================================== //
// Custom Painters                                                     //
// ================================================================== //

class ImprovedSpiralPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const turns = 3.5;
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

    final dotPaint = Paint()..style = PaintingStyle.fill;
    dotPaint.color = Colors.red;
    canvas.drawCircle(Offset(center.dx + 25, center.dy - 20), 6, dotPaint);
    canvas.drawCircle(Offset(center.dx - 30, center.dy + 25), 5, dotPaint);
    dotPaint.color = Colors.yellow.shade700;
    canvas.drawCircle(Offset(center.dx + 38, center.dy + 8), 4, dotPaint);
    canvas.drawCircle(Offset(center.dx - 15, center.dy - 35), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
