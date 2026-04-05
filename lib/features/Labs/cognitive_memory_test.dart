import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/loading_bars.dart';
import 'package:neuroverse/core/responsive.dart';

class CognitiveMemoryTestScreen extends StatefulWidget {
  const CognitiveMemoryTestScreen({super.key});

  @override
  State<CognitiveMemoryTestScreen> createState() => _CognitiveMemoryTestScreenState();
}

// Add these new variables:
  int? _sessionId;
  bool _isSubmitting = false;
  Map<String, Map<String, dynamic>> _testResults = {};  // Store raw data per test component

class _CognitiveMemoryTestScreenState extends State<CognitiveMemoryTestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;

  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color greenAccent = Color(0xFF10B981);

  // Test data
  final List<TestComponent> testComponents = [
    TestComponent(
      name: 'Stroop Test',
      description: 'Color-word interference assessment',
      duration: '3 min',
      isCompleted: false,
      icon: Icons.color_lens_rounded,
    ),
    TestComponent(
      name: 'Word List Recall',
      description: 'Verbal memory and learning test',
      duration: '6 min',
      isCompleted: false,
      icon: Icons.format_list_bulleted_rounded,
    ),
    TestComponent(
      name: 'Clock Drawing',
      description: 'Visuospatial and executive function',
      duration: '3 min',
      isCompleted: false,
      icon: Icons.access_time_rounded,
    ),
    TestComponent(
      name: 'Trail Making',
      description: 'Processing speed and mental flexibility',
      duration: '5 min',
      isCompleted: false,
      icon: Icons.route_rounded,
    ),
  ];

  int get completedCount => testComponents.where((t) => t.isCompleted).length;
  int get totalCount => testComponents.length;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    // Get sessionId from arguments after build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        _sessionId = args['sessionId'];
      });
      _startSession();
    }
  });

  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  // Add this method:
Future<void> _startSession() async {
  if (_sessionId != null) {
    await ApiService.startTestSession(sessionId: _sessionId!);
  }
}
  Future<void> _submitTestItem(String testName, Map<String, dynamic> rawData) async {
  if (_sessionId == null) return;

  final result = await ApiService.addTestItem(
    sessionId: _sessionId!,
    itemName: testName.toLowerCase().replaceAll(' ', '_'),  // stroop_test, n_back_memory, word_list_recall
    itemType: 'cognitive',
    rawData: rawData,
  );

  if (result['success']) {
    _testResults[testName] = rawData;
  }
}
Future<void> _completeSession() async {
  if (_sessionId == null) return;

  setState(() => _isSubmitting = true);

  final result = await ApiService.completeTestSession(sessionId: _sessionId!);

  setState(() => _isSubmitting = false);

  if (mounted) {
    if (result['success']) {
      _showResultsDialog(result['data']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to complete session'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _showResultsDialog(Map<String, dynamic> resultData) {
  final adRisk = (resultData['ad_risk_score'] ?? 0).toDouble();
  final pdRisk = (resultData['pd_risk_score'] ?? 0).toDouble();
  final severity = resultData['severity'] ?? 'low';
  final severityColor = severity == 'high' ? Colors.red : severity == 'medium' ? Colors.orange : greenAccent;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: greenAccent, size: 28),
          const SizedBox(width: 10),
          const Expanded(child: Text('Test Complete', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _resultRow('AD Risk', '${adRisk.toStringAsFixed(1)}%', adRisk > 50 ? Colors.red : greenAccent),
                const SizedBox(height: 8),
                _resultRow('PD Risk', '${pdRisk.toStringAsFixed(1)}%', pdRisk > 50 ? Colors.red : greenAccent),
                const SizedBox(height: 8),
                _resultRow('Severity', severity.toString().toUpperCase(), severityColor),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your cognitive analysis is complete. You can view detailed AI explanations or return to tests.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pop(context);
          },
          child: const Text('Done', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushReplacementNamed(context, '/XAI', arguments: {'result': {...resultData, 'category': 'cognitive'}});
          },
          icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
          label: const Text('View AI Analysis', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: purpleAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
  );
}

Widget _resultRow(String label, String value, Color color) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ),
    ],
  );
}

void _showCompleteDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'All Tests Completed! 🎉',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Ready to analyze your results and get AI-powered insights?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Review Tests',
            style: TextStyle(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _completeSession();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: purpleAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const LoadingBars(color: Colors.white, height: 18, barCount: 5)
              : const Text('Get Results', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
      return WillPopScope(
    onWillPop: () async {
      if (_sessionId != null && completedCount == 0) {
        await ApiService.cancelTestSession(sessionId: _sessionId!);
      }
      return true;
    },
    child:  Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: r.h(20)),
              _buildHeader(r),
              SizedBox(height: r.h(24)),
              _buildAboutCard(r),
              SizedBox(height: r.h(20)),
              _buildProgressCard(r),
              SizedBox(height: r.h(24)),
              _buildBeforeYouStartCard(r),
              SizedBox(height: r.h(24)),
              _buildTestComponentsSection(r),
              SizedBox(height: r.h(30)),
            ],
          ),
        ),
      ),
    ),
      );
  }

  Widget _buildHeader(Responsive r) {
  return _buildAnimatedWidget(
    delay: 0.0,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: r.w(20)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();

              if (_sessionId != null) {
                if (completedCount > 0) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Exit Test?', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: Text('You have completed $completedCount/$totalCount tests. Progress will be lost.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Continue', style: TextStyle(color: Colors.black.withOpacity(0.5))),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ApiService.cancelTestSession(sessionId: _sessionId!);
                            Navigator.pop(ctx);
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text('Exit', style: TextStyle(color: Color(0xFFEF4444))),
                        ),
                      ],
                    ),
                  );
                } else {
                  await ApiService.cancelTestSession(sessionId: _sessionId!);
                  Navigator.pop(context);
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: r.dp(44),
              height: r.dp(44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.w(14)),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Icon(
                Icons.close_rounded,
                size: r.dp(20),
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(width: r.w(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cognitive & Memory',
                  style: TextStyle(
                    fontSize: r.sp(20),
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Assessment',
                  style: TextStyle(
                    fontSize: r.sp(20),
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: r.h(4)),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: r.dp(14), color: Colors.black54),
                    SizedBox(width: r.w(4)),
                    Text(
                      '18-22 minutes',
                      style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w500, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: r.dp(50),
            height: r.dp(50),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(r.w(16)),
            ),
            child: Icon(
              Icons.extension_rounded,
              color: const Color(0xFF8B5CF6),
              size: r.dp(26),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAboutCard(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Container(
          padding: EdgeInsets.all(r.w(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.w(22)),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.dp(44),
                height: r.dp(44),
                decoration: BoxDecoration(
                  color: purpleAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(r.w(14)),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: purpleAccent,
                  size: r.dp(22),
                ),
              ),
              SizedBox(width: r.w(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About This Test',
                      style: TextStyle(
                        fontSize: r.sp(16),
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: r.h(8)),
                    Text(
                      'Comprehensive cognitive assessment measuring attention, executive function, working memory, and verbal recall to detect early signs of cognitive impairment.',
                      style: TextStyle(
                        fontSize: r.sp(13),
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.6),
                        height: 1.5,
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

  Widget _buildProgressCard(Responsive r) {
    double progress = completedCount / totalCount;

    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Container(
          padding: EdgeInsets.all(r.w(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.w(22)),
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
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(6)),
                    decoration: BoxDecoration(
                      color: softLavender,
                      borderRadius: BorderRadius.circular(r.w(12)),
                    ),
                    child: Text(
                      '$completedCount/$totalCount completed',
                      style: TextStyle(
                        fontSize: r.sp(12),
                        fontWeight: FontWeight.w700,
                        color: purpleAccent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(16)),
              // Progress bar
              Container(
                height: r.h(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(r.w(10)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: constraints.maxWidth * progress,
                          height: r.h(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                softLavender,
                                purpleAccent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(r.w(10)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeforeYouStartCard(Responsive r) {
    final tips = [
      'Ensure you are well-rested and alert',
      'Find a distraction-free environment',
      'Do not use any aids or external help',
      'Read instructions carefully before each test',
    ];

    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Container(
          padding: EdgeInsets.all(r.w(20)),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(r.w(22)),
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
                    width: r.dp(36),
                    height: r.dp(36),
                    decoration: BoxDecoration(
                      color: softLavender,
                      borderRadius: BorderRadius.circular(r.w(10)),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: purpleAccent,
                      size: r.dp(20),
                    ),
                  ),
                  SizedBox(width: r.w(12)),
                  Text(
                    'Before You Start',
                    style: TextStyle(
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(16)),
              ...tips.map((tip) => Padding(
                padding: EdgeInsets.only(bottom: r.h(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: r.dp(6),
                      height: r.dp(6),
                      margin: EdgeInsets.only(top: r.h(6)),
                      decoration: BoxDecoration(
                        color: softLavender,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: r.w(12)),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: r.sp(13),
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestComponentsSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnimatedWidget(
          delay: 0.25,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.w(20)),
            child: Text(
              'Test Components',
              style: TextStyle(
                fontSize: r.sp(20),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        SizedBox(height: r.h(16)),
        ...testComponents.asMap().entries.map((entry) {
          int index = entry.key;
          TestComponent test = entry.value;
          return _buildAnimatedWidget(
            delay: 0.3 + (index * 0.05),
            child: _buildTestComponentCard(r, test),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTestComponentCard(Responsive r, TestComponent test) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(6)),
      child: Container(
        padding: EdgeInsets.all(r.w(18)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.w(20)),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: r.dp(48),
                  height: r.dp(48),
                  decoration: BoxDecoration(
                    color: test.isCompleted
                        ? greenAccent.withOpacity(0.15)
                        : purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(r.w(14)),
                  ),
                  child: Icon(
                    test.isCompleted ? Icons.check_circle_rounded : test.icon,
                    color: test.isCompleted ? greenAccent : purpleAccent,
                    size: r.dp(24),
                  ),
                ),
                SizedBox(width: r.w(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            test.name,
                            style: TextStyle(
                              fontSize: r.sp(16),
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(5)),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(r.w(8)),
                            ),
                            child: Text(
                              test.duration,
                              style: TextStyle(
                                fontSize: r.sp(11),
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: r.h(4)),
                      Text(
                        test.description,
                        style: TextStyle(
                          fontSize: r.sp(13),
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.h(14)),
            // Status or Start button
            if (test.isCompleted)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.h(12)),
                decoration: BoxDecoration(
                  color: greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(r.w(14)),
                  border: Border.all(
                    color: greenAccent.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: greenAccent,
                      size: r.dp(18),
                    ),
                    SizedBox(width: r.w(8)),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: r.sp(14),
                        fontWeight: FontWeight.w700,
                        color: greenAccent,
                      ),
                    ),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  // Navigate to actual test screen and get result
    String routeName = '';
    if (test.name == 'Stroop Test') {
      routeName = '/test/stroop-test';
    } else if (test.name == 'N-Back Memory') {
      routeName = '/test/nback-test';
    } else if (test.name == 'Word List Recall') {
      routeName = '/test/word-recall-test';
    } else if (test.name == 'Clock Drawing') {
      routeName = '/test/clock-drawing-test';
    } else if (test.name == 'Trail Making') {
      routeName = '/test/trail-making-test';
    }

    if (routeName.isNotEmpty) {
      // Navigate and wait for result
      final result = await Navigator.pushNamed(context, routeName);

      if (result != null && result is Map<String, dynamic>) {
        // Submit test item to API
        await _submitTestItem(test.name, result);

        // Mark as completed
        setState(() {
          final index = testComponents.indexWhere((t) => t.name == test.name);
          if (index != -1) {
            testComponents[index] = TestComponent(
              name: test.name,
              description: test.description,
              duration: test.duration,
              isCompleted: true,
              icon: test.icon,
            );
          }
        });

        // If all tests completed, show complete dialog
        if (completedCount == totalCount) {
          _showCompleteDialog();
        }
      }
    }
  },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: r.h(14)),
                  decoration: BoxDecoration(
                    color: purpleAccent,
                    borderRadius: BorderRadius.circular(r.w(14)),
                    boxShadow: [
                      BoxShadow(
                        color: purpleAccent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: r.dp(20),
                      ),
                      SizedBox(width: r.w(8)),
                      Text(
                        'Start Test',
                        style: TextStyle(
                          fontSize: r.sp(14),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

class TestComponent {
  final String name;
  final String description;
  final String duration;
  bool isCompleted;  // Remove 'final'
  final IconData icon;

  TestComponent({
    required this.name,
    required this.description,
    required this.duration,
    required this.isCompleted,
    required this.icon,
  });
}
