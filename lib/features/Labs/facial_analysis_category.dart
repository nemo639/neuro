import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class FacialAnalysisCategoryScreen extends StatefulWidget {
  const FacialAnalysisCategoryScreen({super.key});

  @override
  State<FacialAnalysisCategoryScreen> createState() =>
      _FacialAnalysisCategoryScreenState();
}

int? _sessionId;
bool _isSubmitting = false;
Map<String, Map<String, dynamic>> _testResults = {};

class _FacialAnalysisCategoryScreenState
    extends State<FacialAnalysisCategoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pageController;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color pinkAccent = Color(0xFFEC4899);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color blueAccent = Color(0xFF3B82F6);

  final List<_TestComponent> testComponents = [
    _TestComponent(
      name: 'Facial Analysis',
      description: 'Blink rate, smile dynamics & expression range',
      duration: '2 min',
      isCompleted: false,
      icon: Icons.face_retouching_natural_rounded,
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() => _sessionId = args['sessionId']);
        _startSession();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_sessionId != null) {
      await ApiService.startTestSession(sessionId: _sessionId!);
    }
  }

  Future<void> _submitTestItem(
      String testName, Map<String, dynamic> rawData) async {
    if (_sessionId == null) return;

    final result = await ApiService.addTestItem(
      sessionId: _sessionId!,
      itemName: testName.toLowerCase().replaceAll(' ', '_'),
      itemType: 'facial',
      rawData: rawData,
    );

    if (result['success']) {
      _testResults[testName] = rawData;
    }
  }

  Future<void> _completeSession() async {
    if (_sessionId == null) return;

    setState(() => _isSubmitting = true);

    final result =
        await ApiService.completeTestSession(sessionId: _sessionId!);

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
    final severityColor = severity == 'high'
        ? Colors.red
        : severity == 'medium'
            ? Colors.orange
            : greenAccent;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: greenAccent, size: 28),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Test Complete',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
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
                  _resultRow('AD Risk', '${adRisk.toStringAsFixed(1)}%',
                      adRisk > 50 ? Colors.red : greenAccent),
                  const SizedBox(height: 8),
                  _resultRow('PD Risk', '${pdRisk.toStringAsFixed(1)}%',
                      pdRisk > 50 ? Colors.red : greenAccent),
                  const SizedBox(height: 8),
                  _resultRow('Severity', severity.toString().toUpperCase(),
                      severityColor),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your facial analysis is complete. You can view detailed AI explanations or return to tests.',
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
              Navigator.pushReplacementNamed(context, '/XAI',
                  arguments: {'result': resultData});
            },
            icon: const Icon(Icons.auto_awesome_rounded,
                size: 18, color: Colors.white),
            label: const Text('View AI Analysis',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: blueAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
        Text(label,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Test Completed!',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Ready to analyze your facial data and get AI-powered insights?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Review',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeSession();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: pinkAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Get Results',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        if (_sessionId != null && completedCount == 0) {
          await ApiService.cancelTestSession(sessionId: _sessionId!);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildAboutCard(),
                const SizedBox(height: 20),
                _buildProgressCard(),
                const SizedBox(height: 24),
                _buildBeforeYouStartCard(),
                const SizedBox(height: 24),
                _buildTestComponentsSection(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
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
              onTap: () async {
                HapticFeedback.lightImpact();
                if (_sessionId != null && completedCount > 0) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Leave Test?',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      content: const Text(
                          'You have completed tests. Your progress will be saved.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Stay',
                              style: TextStyle(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          },
                          child: const Text('Leave',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                } else {
                  if (_sessionId != null) {
                    await ApiService.cancelTestSession(
                        sessionId: _sessionId!);
                  }
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Facial Analysis',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  Text('2-3 minutes',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: pinkAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.face_retouching_natural_rounded,
                  color: pinkAccent, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return _buildAnimatedWidget(
      delay: 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pinkAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.info_outline_rounded, color: pinkAccent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('About This Assessment',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'AI-powered facial movement analysis evaluates blink patterns, smile dynamics, expression range and hypomimia for PD screening.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withValues(alpha: 0.55)),
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

  Widget _buildProgressCard() {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Progress',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('$completedCount/$totalCount completed',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pinkAccent)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 10, color: Colors.grey.shade100),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 10,
                      width: MediaQuery.of(context).size.width *
                          progress *
                          0.82,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [pinkAccent, Color(0xFFDB2777)]),
                        borderRadius: BorderRadius.circular(6),
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

  Widget _buildBeforeYouStartCard() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                      color: Colors.amber, size: 22),
                  SizedBox(width: 10),
                  Text('Before You Start',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              _buildTipItem(
                  Icons.light_mode_rounded,
                  'Good lighting',
                  'Face a window or lamp for clear detection'),
              const SizedBox(height: 10),
              _buildTipItem(
                  Icons.straighten_rounded,
                  'Arm\'s length',
                  'Hold phone steady at face level'),
              const SizedBox(height: 10),
              _buildTipItem(
                  Icons.visibility_rounded,
                  'Remove glasses',
                  'Better eye tracking without glasses'),
              const SizedBox(height: 10),
              _buildTipItem(
                  Icons.face_rounded,
                  'Follow prompts',
                  'Perform each task as instructed on screen'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestComponentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnimatedWidget(
          delay: 0.25,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Test Components',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
          ),
        ),
        const SizedBox(height: 16),
        ...testComponents.asMap().entries.map((entry) {
          int index = entry.key;
          _TestComponent test = entry.value;
          return _buildAnimatedWidget(
            delay: 0.3 + (index * 0.05),
            child: _buildTestComponentCard(test),
          );
        }),
      ],
    );
  }

  Widget _buildTestComponentCard(_TestComponent test) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: test.isCompleted
                        ? greenAccent.withValues(alpha: 0.15)
                        : pinkAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    test.isCompleted
                        ? Icons.check_circle_rounded
                        : test.icon,
                    color: test.isCompleted ? greenAccent : pinkAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(test.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(test.duration,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black
                                        .withValues(alpha: 0.5))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(test.description,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  Colors.black.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (test.isCompleted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: greenAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: greenAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: greenAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Completed',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: greenAccent)),
                  ],
                ),
              )
            else
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();

                  final result = await Navigator.pushNamed(
                      context, '/test/facial-analysis');

                  if (result != null && result is Map<String, dynamic>) {
                    await _submitTestItem(test.name, result);

                    setState(() {
                      final index = testComponents
                          .indexWhere((t) => t.name == test.name);
                      if (index != -1) {
                        testComponents[index] = _TestComponent(
                          name: test.name,
                          description: test.description,
                          duration: test.duration,
                          isCompleted: true,
                          icon: test.icon,
                        );
                      }
                    });

                    if (completedCount == totalCount) {
                      _showCompleteDialog();
                    }
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: pinkAccent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: pinkAccent.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Start Test',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWidget(
      {required double delay, required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _pageController,
        curve: Interval(delay, math.min(delay + 0.3, 1.0),
            curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _pageController,
          curve: Interval(delay, math.min(delay + 0.3, 1.0),
              curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}

class _TestComponent {
  final String name;
  final String description;
  final String duration;
  bool isCompleted;
  final IconData icon;

  _TestComponent({
    required this.name,
    required this.description,
    required this.duration,
    required this.isCompleted,
    required this.icon,
  });
}
