import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/cache_service.dart';
import 'package:neuroverse/core/responsive.dart';
import 'package:neuroverse/core/shimmer_loading.dart';

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;

  // Track expanded state for each category
  Map<int, bool> expandedCategories = {
    0: true,  // Speech & Language expanded by default
    1: false,
    2: false,
  };

// Add these new variables:
bool _isLoading = true;
Map<String, dynamic>? _testDashboard;
int _completedTestsCount = 0;
Map<String, int> _categoryCompletedTests = {};

  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color orangeAccent = Color(0xFFF97316);
  static const Color pinkAccent = Color(0xFFEC4899);

  // Test categories data
  final List<TestCategory> testCategories = [
    TestCategory(
      title: 'Speech & Language',
      description: 'Voice analysis and language comprehension',
      icon: Icons.mic_rounded,
      color: Color(0xFF3B82F6),
      bgColor: Color(0xFFDBEAFE),
      route: '/test/speech-language',
      tests: [
        TestItem(name: 'Story Recall', duration: '5 min'),
        TestItem(name: 'Sustained Vowel', duration: '2 min'),
        TestItem(name: 'Picture Description', duration: '4 min'),
      ],
    ),
    TestCategory(
      title: 'Cognitive & Memory',
      description: 'Mental agility and memory assessment',
      icon: Icons.extension_rounded,
      color: Color(0xFF8B5CF6),
      bgColor: Color(0xFFF3E8FF),
      route: '/test/cognitive-memory',
      tests: [
        TestItem(name: 'Stroop Test', duration: '3 min'),
        TestItem(name: 'Word List Recall', duration: '6 min'),
        TestItem(name: 'Clock Drawing', duration: '3 min'),
        TestItem(name: 'Trail Making', duration: '5 min'),
      ],
    ),
    TestCategory(
      title: 'Motor Functions',
      description: 'Movement and coordination tests',
      icon: Icons.gesture_rounded,
      color: Color(0xFFF97316),
      bgColor: Color(0xFFFFF7ED),
      route: '/test/motor-functions',
      tests: [
        TestItem(name: 'Resting Tremor', duration: '2 min'),
        TestItem(name: 'Spiral Drawing', duration: '3 min'),
        TestItem(name: 'Meander Drawing', duration: '3 min'),
      ],
    ),
    TestCategory(
      title: 'Facial Analysis',
      description: 'Facial expression & movement analysis',
      icon: Icons.face_retouching_natural_rounded,
      color: Color(0xFFEC4899),
      bgColor: Color(0xFFFCE7F3),
      route: '/test/facial-eye',
      tests: [
        TestItem(name: 'Facial Analysis', duration: '2 min'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _loadData();  // Add this
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  void _applyTestData(Map<String, dynamic> result) {
    _completedTestsCount = 0;
    _categoryCompletedTests = {};
    if (result['success'] == true) {
      _testDashboard = result['data'] as Map<String, dynamic>?;
      const categoryIndexMap = {'speech': 0, 'cognitive': 1, 'motor': 2, 'facial': 3};
      final categories = _testDashboard?['categories'] as List? ?? [];
      for (var cat in categories) {
        final catName = (cat['category'] ?? '') as String;
        final completedSessions = (cat['total_completed'] ?? 0) as int;
        _categoryCompletedTests[catName] = completedSessions;
        if (completedSessions > 0) {
          final idx = categoryIndexMap[catName];
          if (idx != null && idx < testCategories.length) {
            _completedTestsCount += testCategories[idx].tests.length;
          }
        }
      }
    }
  }

  Future<void> _loadData() async {
    // Show cached data instantly if available
    final cached = await CacheService.get('tests_dashboard');
    if (cached != null && mounted) {
      setState(() {
        _applyTestData(cached);
        _isLoading = false;
      });
    }

    final result = await ApiService.getTestDashboard();

    // Cache the fresh data
    await CacheService.set('tests_dashboard', result);

    if (mounted) {
      setState(() {
        _applyTestData(result);
        _isLoading = false;
      });
    }
  }
  int get completedTests {
   return _completedTestsCount;
  }

  int get totalTests {
    return testCategories.fold(0, (sum, cat) => sum + cat.tests.length);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: ShimmerLoading(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: r.w(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: r.h(16)),
                  // Header
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    SkeletonLine(width: r.w(120), height: r.h(22)),
                    SkeletonCircle(size: r.dp(40)),
                  ]),
                  SizedBox(height: r.h(8)),
                  SkeletonLine(width: r.w(220), height: r.h(14)),
                  SizedBox(height: r.h(24)),
                  // Progress card
                  SkeletonBox(width: double.infinity, height: r.h(100), borderRadius: r.w(20)),
                  SizedBox(height: r.h(24)),
                  // Category tabs
                  Row(children: [
                    SkeletonBox(width: r.w(80), height: r.h(36), borderRadius: r.w(18)),
                    SizedBox(width: r.w(10)),
                    SkeletonBox(width: r.w(80), height: r.h(36), borderRadius: r.w(18)),
                    SizedBox(width: r.w(10)),
                    SkeletonBox(width: r.w(80), height: r.h(36), borderRadius: r.w(18)),
                  ]),
                  SizedBox(height: r.h(24)),
                  // Test cards
                  SkeletonBox(width: double.infinity, height: r.h(90), borderRadius: r.w(16)),
                  SizedBox(height: r.h(12)),
                  SkeletonBox(width: double.infinity, height: r.h(90), borderRadius: r.w(16)),
                  SizedBox(height: r.h(12)),
                  SkeletonBox(width: double.infinity, height: r.h(90), borderRadius: r.w(16)),
                  SizedBox(height: r.h(12)),
                  SkeletonBox(width: double.infinity, height: r.h(90), borderRadius: r.w(16)),
                  SizedBox(height: r.h(24)),
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
                    SizedBox(height: r.h(20)),
                    _buildHeader(r),
                    SizedBox(height: r.h(24)),
                    _buildOverallProgress(r),
                    SizedBox(height: r.h(24)),
                    _buildTestCategories(r),
                    SizedBox(height: r.h(100)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Modules',
                      style: TextStyle(
                        fontSize: r.sp(32),
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: r.h(6)),
                    Text(
                      'Multimodal neurological assessments',
                      style: TextStyle(
                        fontSize: r.sp(14),
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: r.dp(48),
                  height: r.dp(48),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(r.w(16)),
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    color: Colors.white,
                    size: r.dp(24),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallProgress(Responsive r) {
    double progressPercent = completedTests / totalTests;
    int percentDisplay = (progressPercent * 100).round();

    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Container(
          padding: EdgeInsets.all(r.dp(20)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.w(24)),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Progress',
                      style: TextStyle(
                        fontSize: r.sp(13),
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(height: r.h(6)),
                    Text(
                      '$completedTests/$totalTests Completed',
                      style: TextStyle(
                        fontSize: r.sp(24),
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: r.h(10)),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(6)),
                          decoration: BoxDecoration(
                            color: mintGreen.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(r.w(10)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sensors_rounded,
                                size: r.dp(14),
                                color: Colors.black.withOpacity(0.6),
                              ),
                              SizedBox(width: r.w(6)),
                              Text(
                                'Sensor-based AI screening',
                                style: TextStyle(
                                  fontSize: r.sp(11),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.w(16)),
              _buildCircularProgress(percentDisplay, progressPercent, r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularProgress(int percent, double progress, Responsive r) {
    final size = r.dp(70);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: CircularProgressPainter(
              progress: progress,
              strokeWidth: r.dp(6),
              backgroundColor: Colors.black.withOpacity(0.08),
              progressColor: mintGreen,
            ),
          ),
          Center(
            child: Text(
              '$percent%',
              style: TextStyle(
                fontSize: r.sp(16),
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCategories(Responsive r) {
    return Column(
      children: List.generate(testCategories.length, (index) {
        return _buildAnimatedWidget(
          delay: 0.15 + (index * 0.05),
          child: _buildTestCategoryCard(index, testCategories[index], r),
        );
      }),
    );
  }

  Widget _buildTestCategoryCard(int index, TestCategory category, Responsive r) {
    bool isExpanded = expandedCategories[index] ?? false;

    // Map index to backend category key for completion lookup
    const indexToCategoryKey = {0: 'speech', 1: 'cognitive', 2: 'motor', 3: 'facial'};
    final catKey = indexToCategoryKey[index] ?? '';
    final isCompleted = (_categoryCompletedTests[catKey] ?? 0) > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isCompleted ? mintGreen.withOpacity(0.5) : Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header - tap to expand/collapse
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  expandedCategories[index] = !isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isCompleted ? mintGreen.withOpacity(0.3) : category.bgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_circle_rounded : category.icon,
                        color: isCompleted ? const Color(0xFF10B981) : category.color,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCompleted ? 'Completed' : category.description,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isCompleted ? const Color(0xFF10B981) : Colors.black.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCompleted ? mintGreen.withOpacity(0.3) : category.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isCompleted ? 'Done' : '${category.tests.length} tests',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isCompleted ? const Color(0xFF10B981) : category.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black.withOpacity(0.4),
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildTestList(category),
              crossFadeState: isExpanded 
                  ? CrossFadeState.showSecond 
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestList(TestCategory category) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Divider(
            color: Colors.black.withOpacity(0.06),
            height: 1,
          ),
          const SizedBox(height: 12),
          ...category.tests.map((test) => _buildTestItem(test, category)).toList(),
          const SizedBox(height: 8),
          // View All / Start button
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              // Navigate to the specific test category detail screen
               // Map route to category name for API
    String categoryName = '';
    if (category.route == '/test/speech-language') {
      categoryName = 'speech';
    } else if (category.route == '/test/cognitive-memory') {
      categoryName = 'cognitive';
    } else if (category.route == '/test/motor-functions') {
      categoryName = 'motor';
    } else if (category.route == '/test/gait-movement') {
      categoryName = 'gait';
    } else if (category.route == '/test/facial-eye') {
      categoryName = 'facial';
    }

    if (categoryName.isNotEmpty) {
      // Create test session first
      var result = await ApiService.createTestSession(category: categoryName);
      
      // If blocked by an incomplete session, cancel it and retry
      if (!result['success'] && (result['error'] ?? '').toString().contains('incomplete')) {
        final listResult = await ApiService.listTestSessions(status: 'created');
        if (listResult['success'] && listResult['data']?['sessions'] != null) {
          for (var s in listResult['data']['sessions']) {
            await ApiService.cancelTestSession(sessionId: s['id']);
          }
        }
        final listResult2 = await ApiService.listTestSessions(status: 'in_progress');
        if (listResult2['success'] && listResult2['data']?['sessions'] != null) {
          for (var s in listResult2['data']['sessions']) {
            await ApiService.cancelTestSession(sessionId: s['id']);
          }
        }
        // Retry creating session
        result = await ApiService.createTestSession(category: categoryName);
      }
      
      if (result['success']) {
        final sessionId = result['data']['id'];
        await Navigator.pushNamed(
          context,
          category.route,
          arguments: {'sessionId': sessionId, 'category': categoryName},
        );
        // Refresh progress when user returns from test
        if (mounted) _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to start test'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${category.title} tests coming soon!'),
          backgroundColor: category.color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: category.color.withOpacity(0.4),
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
                    'Start Assessment',
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
    );
  }

  Widget _buildTestItem(TestItem test, TestCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              test.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
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
class TestCategory {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String route;
  final List<TestItem> tests;

  TestCategory({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.route,
    required this.tests,
  });
}

class TestItem {
  final String name;
  final String duration;

  TestItem({
    required this.name,
    required this.duration,
  });
}

// Circular Progress Painter
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}