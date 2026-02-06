import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class MotorFunctionsTestScreen extends StatefulWidget {
  const MotorFunctionsTestScreen({super.key});

  @override
  State<MotorFunctionsTestScreen> createState() => _MotorFunctionsTestScreenState();
}

class _MotorFunctionsTestScreenState extends State<MotorFunctionsTestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
int? _sessionId;
bool _isSubmitting = false;
Map<String, Map<String, dynamic>> _testResults = {};
  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color greenAccent = Color(0xFF10B981);

  // Test data
  final List<TestComponent> testComponents = [
    TestComponent(
      name: 'Finger Tapping',
      description: 'Measure tapping speed and rhythm',
      duration: '2 min',
      isCompleted: false,
      icon: Icons.touch_app_rounded,
    ),
    TestComponent(
      name: 'Spiral Drawing',
      description: 'Assess hand tremor and coordination',
      duration: '3 min',
      isCompleted: false,
      icon: Icons.gesture_rounded,
    ),
    TestComponent(
      name: 'Gait Analysis',
      description: 'Evaluate walking patterns via sensors',
      duration: '5 min',
      isCompleted: false,
      icon: Icons.directions_walk_rounded,
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
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() => _sessionId = args['sessionId']);
      _startSession();
    }
  });

}

  Future<void> _startSession() async {
  if (_sessionId != null) {
    await ApiService.startTestSession(sessionId: _sessionId!);
  }
}

Future<void> _submitTestItem(String testName, Map<String, dynamic> rawData) async {
  if (_sessionId == null) return;
  final result = await ApiService.addTestItem(
    sessionId: _sessionId!,
    itemName: testName.toLowerCase().replaceAll(' ', '_'),
    itemType: 'motor',
    rawData: rawData,
  );
  if (result['success']) _testResults[testName] = rawData;
}

Future<void> _completeSession() async {
  if (_sessionId == null) return;
  setState(() => _isSubmitting = true);
  final result = await ApiService.completeTestSession(sessionId: _sessionId!);
  setState(() => _isSubmitting = false);
  if (mounted) {
    if (result['success']) {
      Navigator.pushReplacementNamed(context, '/XAI', arguments: {'result': result['data']});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed'), backgroundColor: Colors.red),
      );
    }
  }
}

void _showCompleteDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('All Tests Completed! 🎉', style: TextStyle(fontWeight: FontWeight.w700)),
      content: const Text('Ready to analyze your motor functions?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Review', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: () { Navigator.pop(context); _completeSession(); },
          style: ElevatedButton.styleFrom(backgroundColor: orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Get Results', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
    onWillPop: () async {
      if (_sessionId != null && completedCount == 0) {
        await ApiService.cancelTestSession(sessionId: _sessionId!);
      }
      return true;
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
            onTap: () {
              HapticFeedback.lightImpact();
              if (_sessionId != null && completedCount == 0) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Exit Test?', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text('You haven’t completed any tests yet. Progress will be lost.'),
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
                Navigator.pop(context);
              }
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
                  'Motor Functions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'Assessment',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '10-12 minutes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pan_tool_rounded,
              color: Color(0xFFF97316),
              size: 26,
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildAboutCard() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: orangeAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: orangeAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About This Test',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Movement and coordination assessment to detect motor symptoms including tremor, bradykinesia, and gait abnormalities associated with neurological conditions.',
                      style: TextStyle(
                        fontSize: 13,
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

  Widget _buildProgressCard() {
    double progress = completedCount / totalCount;
    
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
                  const Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedCount/$totalCount completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: constraints.maxWidth * progress,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFFED7AA),
                                orangeAccent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
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

  Widget _buildBeforeYouStartCard() {
    final tips = [
      'Place your device on a stable, flat surface',
      'Ensure good lighting for camera-based tests',
      'Remove rings or accessories from hands',
      'Wear comfortable shoes for gait analysis',
    ];

    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFED7AA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: orangeAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Before You Start',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFED7AA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                          fontSize: 13,
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

  Widget _buildTestComponentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnimatedWidget(
          delay: 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Test Components',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...testComponents.asMap().entries.map((entry) {
          int index = entry.key;
          TestComponent test = entry.value;
          return _buildAnimatedWidget(
            delay: 0.3 + (index * 0.05),
            child: _buildTestComponentCard(test),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTestComponentCard(TestComponent test) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: test.isCompleted 
                        ? greenAccent.withOpacity(0.15)
                        : orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    test.isCompleted ? Icons.check_circle_rounded : test.icon,
                    color: test.isCompleted ? greenAccent : orangeAccent,
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
                          Text(
                            test.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              test.duration,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        test.description,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
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
                  color: greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
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
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 14,
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
    
    String routeName = '';
    if (test.name == 'Finger Tapping') {
      routeName = '/test/finger-tapping-test';
    } else if (test.name == 'Spiral Drawing') {
      routeName = '/test/spiral-drawing-test';
    } else if (test.name == 'Gait Analysis') {
      routeName = '/test/gait-analysis';
    }

    if (routeName.isNotEmpty) {
      final result = await Navigator.pushNamed(context, routeName);
      if (result != null && result is Map<String, dynamic>) {
        await _submitTestItem(test.name, result);
        setState(() {
          final index = testComponents.indexWhere((t) => t.name == test.name);
          if (index != -1) {
            testComponents[index] = TestComponent(
              name: test.name, description: test.description,
              duration: test.duration, isCompleted: true, icon: test.icon,
            );
          }
        });
        if (completedCount == totalCount) _showCompleteDialog();
      }
    }
  },
  child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: orangeAccent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: orangeAccent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Start Test',
                        style: TextStyle(
                          fontSize: 14,
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
  bool isCompleted;
  final IconData icon;

  TestComponent({
    required this.name,
    required this.description,
    required this.duration,
    required this.isCompleted,
    required this.icon,
  });
}