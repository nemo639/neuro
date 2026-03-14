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
      for (final cat in ['cognitive', 'speech', 'motor']) {
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
    }

    if (mounted) setState(() {});
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
        icon: Icons.pan_tool_rounded,
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
        icon: Icons.psychology_rounded,
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
                    _buildMethodSelector(),
                    const SizedBox(height: 20),
                    // Dynamic content based on selected XAI method
                    _buildSelectedMethodContent(),
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
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(module.icon,
                              color:
                                  isSelected ? Colors.white : module.color,
                              size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(module.name,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black.withOpacity(0.6))),
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
              itemCount: _xaiMethods.length,
              itemBuilder: (context, index) {
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
              const SizedBox(height: 6),
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
              const SizedBox(height: 18),
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
              const SizedBox(height: 8),
              Text(
                'How small perturbations in each feature locally affect the prediction:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 8),
              Text(
                'Attribution scores from baseline (zero) to actual input via gradient integration:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5)),
              ),
              const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
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
              // Actionable insights
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: darkCard.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6))
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
                              color: tealAccent,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.tips_and_updates_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Actionable Recommendations',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
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
              const SizedBox(height: 16),
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
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: darkCard.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6))
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
                        color: indigoAccent,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.medical_information_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Clinical Interpretation',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Based on neuropsychological assessment reporting standards',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 14),
              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.summarize_rounded,
                        color: Colors.white.withOpacity(0.7), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(selectedModule.summary,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8),
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
                          color: Colors.white.withOpacity(0.6))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
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
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
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
              const SizedBox(height: 20),
              SizedBox(
                height: 130,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: selectedModule.featureImportance
                      .asMap()
                      .entries
                      .map((entry) {
                    final feature = entry.value;
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
                                  selectedModule.color.withOpacity(0.5)
                                ]),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      selectedModule.color.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(feature.name,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.5))),
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

  /// Horizontal bar for SHAP-style values
  Widget _buildHorizontalBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    String badge = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(value.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              if (badge.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(badge,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ratio = (value / maxValue).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: constraints.maxWidth * ratio,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [color.withOpacity(0.8), color]),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
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
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
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

  /// Actionable insight row
  Widget _buildActionableRow(ActionableInsight action) {
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
              color: action.priority == 'high' ? yellowAccent : tealAccent,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: (action.priority == 'high' ? yellowAccent : tealAccent)
                      .withOpacity(0.5),
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
                Row(
                  children: [
                    Text(action.feature,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: action.priority == 'high'
                                ? yellowAccent
                                : tealAccent)),
                    if (action.benefit.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(action.benefit,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.5))),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(action.recommendation,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.3)),
              ],
            ),
          ),
        ],
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

  /// Clinical interpretation row
  Widget _buildInterpretationRow(InterpretationPoint point) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: point.color.withOpacity(0.3)),
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
                      color: point.color.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.6),
                    height: 1.3)),
            if (point.recommendation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 14, color: Colors.white.withOpacity(0.4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(point.recommendation,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.45),
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
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E3A5F),
                  Color(0xFF2D5A87),
                  Color(0xFF1E3A5F)
                ]),
            boxShadow: [
              BoxShadow(
                  color: blueAccent.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                      painter: SpectrogramPainter(
                          animation: _pulseController.value)),
                ),
                Positioned(
                  left: 60,
                  top: 30,
                  child: Container(
                    width: 50,
                    height: 70,
                    decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          Colors.red.withOpacity(0.6),
                          Colors.red.withOpacity(0.0)
                        ]),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Positioned(
                  right: 80,
                  top: 40,
                  child: Container(
                    width: 60,
                    height: 50,
                    decoration: BoxDecoration(
                        gradient: RadialGradient(colors: [
                          Colors.orange.withOpacity(0.7),
                          Colors.orange.withOpacity(0.0)
                        ]),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                // Label: "Audio Waveform Analysis"
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('Audio Waveform Analysis',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
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
            size: const Size(120, 120), painter: ImprovedSpiralPainter()),
      ),
    );
  }

  Widget _buildBarsVisualization() {
    final barData = [0.95, 0.75, 0.45, 0.35, 0.70, 0.85, 0.25, 0.55];
    final barColors = [
      greenAccent, greenAccent, yellowAccent, redAccent,
      greenAccent, greenAccent, redAccent, yellowAccent,
    ];

    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [softLavender.withOpacity(0.5), Colors.white]),
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
              final heightMul = 0.95 + (_pulseController.value * 0.05);
              return Container(
                width: 28,
                height: 100 * barData[index] * heightMul,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        barColors[index],
                        barColors[index].withOpacity(0.6)
                      ]),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: barColors[index].withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
              );
            },
          );
        }),
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
  });
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

class SpectrogramPainter extends CustomPainter {
  final double animation;
  SpectrogramPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

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
