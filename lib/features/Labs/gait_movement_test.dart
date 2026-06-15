import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/responsive.dart';

class GaitMovementTestScreen extends StatefulWidget {
  const GaitMovementTestScreen({super.key});

  @override
  State<GaitMovementTestScreen> createState() => _GaitMovementTestScreenState();
}

class _GaitMovementTestScreenState extends State<GaitMovementTestScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
  int? _sessionId;
bool _isSubmitting = false;
  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color greenAccent = Color(0xFF10B981);

  // Individual test items (for display in progress)
  final List<String> testItems = [
  'Gait Assessment',
];

  // Is the comprehensive test completed
  bool isTestCompleted = false;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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

Future<void> _submitAndComplete(Map<String, dynamic> rawData) async {
  if (_sessionId == null) return;

  // Submit all gait data as one item
  await ApiService.addTestItem(
    sessionId: _sessionId!,
    itemName: 'gait_comprehensive',
    itemType: 'gait',
    rawData: rawData,
  );

  setState(() => _isSubmitting = true);
  final result = await ApiService.completeTestSession(sessionId: _sessionId!);
  setState(() => _isSubmitting = false);

  if (mounted) {
    if (result['success']) {
      _showResultsDialog(result['data']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Failed'), backgroundColor: Colors.red),
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
            'Your gait analysis is complete. You can view detailed AI explanations or return to tests.',
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
            Navigator.pushReplacementNamed(context, '/XAI', arguments: {'result': resultData});
          },
          icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
          label: const Text('View AI Analysis', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: tealAccent,
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return WillPopScope(
    onWillPop: () async {
      if (_sessionId != null && !isTestCompleted) {
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
              SizedBox(height: r.h(20)),
              _buildHeader(r),
              SizedBox(height: r.h(24)),
              _buildAboutCard(r),
              SizedBox(height: r.h(20)),
              _buildProgressCard(r),
              SizedBox(height: r.h(24)),
              _buildTestIncludesCard(r),
              SizedBox(height: r.h(24)),
              _buildBeforeYouStartCard(r),
              SizedBox(height: r.h(24)),
              _buildTestComponentSection(r),
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
            onTap: () {
              HapticFeedback.lightImpact();
              if (_sessionId != null && !isTestCompleted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Exit Test?', style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text('You have started this test. Progress will be lost if you exit.'),
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
              width: r.dp(44),
              height: r.dp(44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.w(14)),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: r.dp(18),
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
                  'Gait & Movement',
                  style: TextStyle(
                    fontSize: r.sp(20),
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                    Icon(
                      Icons.schedule_rounded,
                      size: r.dp(14),
                      color: Colors.black.withOpacity(0.5),
                    ),
                    SizedBox(width: r.w(4)),
                    Text(
                      '10 minutes',
                      style: TextStyle(
                        fontSize: r.sp(13),
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: r.w(12)),
          Container(
            width: r.dp(50),
            height: r.dp(50),
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(r.w(16)),
            ),
            child: Icon(
              Icons.directions_walk_rounded,
              color: const Color(0xFF14B8A6),
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
                  color: tealAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(r.w(14)),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: tealAccent,
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
                      'Comprehensive gait and movement analysis using device sensors to evaluate walking patterns, balance, and postural stability for early detection of movement disorders.',
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
    int completedCount = isTestCompleted ? 3 : 0;
    int totalCount = 3;
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
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(r.w(12)),
                    ),
                    child: Text(
                      '$completedCount/$totalCount completed',
                      style: TextStyle(
                        fontSize: r.sp(12),
                        fontWeight: FontWeight.w700,
                        color: tealAccent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(16)),
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
                                const Color(0xFFCCFBF1),
                                tealAccent,
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

  Widget _buildTestIncludesCard(Responsive r) {
    final testDetails = [
      {'name': 'Walking Test', 'duration': '5 min', 'icon': Icons.directions_walk_rounded},
      {'name': 'Turn-in-Place', 'duration': '2 min', 'icon': Icons.rotate_right_rounded},
      {'name': 'Balance Assessment', 'duration': '3 min', 'icon': Icons.accessibility_new_rounded},
    ];

    return _buildAnimatedWidget(
      delay: 0.2,
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
                children: [
                  Container(
                    width: r.dp(36),
                    height: r.dp(36),
                    decoration: BoxDecoration(
                      color: tealAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(r.w(10)),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      color: tealAccent,
                      size: r.dp(18),
                    ),
                  ),
                  SizedBox(width: r.w(12)),
                  Text(
                    'This Test Includes',
                    style: TextStyle(
                      fontSize: r.sp(16),
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.h(16)),
              ...testDetails.map((test) => Padding(
                padding: EdgeInsets.only(bottom: r.h(12)),
                child: Row(
                  children: [
                    Container(
                      width: r.dp(40),
                      height: r.dp(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(r.w(12)),
                      ),
                      child: Icon(
                        test['icon'] as IconData,
                        color: tealAccent,
                        size: r.dp(20),
                      ),
                    ),
                    SizedBox(width: r.w(12)),
                    Expanded(
                      child: Text(
                        test['name'] as String,
                        style: TextStyle(
                          fontSize: r.sp(14),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: r.w(8)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(5)),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(r.w(8)),
                      ),
                      child: Text(
                        test['duration'] as String,
                        style: TextStyle(
                          fontSize: r.sp(11),
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.5),
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

  Widget _buildBeforeYouStartCard(Responsive r) {
    final tips = [
      'Clear a safe walking path of at least 10 meters',
      'Wear comfortable, flat-soled shoes',
      'Keep your phone in your pocket during the test',
      'Have a wall or support nearby for safety',
    ];

    return _buildAnimatedWidget(
      delay: 0.25,
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
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(r.w(10)),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: tealAccent,
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
                        color: const Color(0xFFCCFBF1),
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

  Widget _buildTestComponentSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAnimatedWidget(
          delay: 0.3,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.w(20)),
            child: Text(
              'Test Component',
              style: TextStyle(
                fontSize: r.sp(20),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        SizedBox(height: r.h(16)),
        _buildAnimatedWidget(
          delay: 0.35,
          child: _buildComprehensiveTestCard(r),
        ),
      ],
    );
  }

  Widget _buildComprehensiveTestCard(Responsive r) {
    return Padding(
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
          children: [
            Row(
              children: [
                Container(
                  width: r.dp(56),
                  height: r.dp(56),
                  decoration: BoxDecoration(
                    color: isTestCompleted
                        ? greenAccent.withOpacity(0.15)
                        : tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(r.w(16)),
                  ),
                  child: Icon(
                    isTestCompleted
                        ? Icons.check_circle_rounded
                        : Icons.directions_walk_rounded,
                    color: isTestCompleted ? greenAccent : tealAccent,
                    size: r.dp(28),
                  ),
                ),
                SizedBox(width: r.w(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Gait Analysis',
                        style: TextStyle(
                          fontSize: r.sp(17),
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: r.h(4)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(5)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(r.w(8)),
                        ),
                        child: Text(
                          '10 min',
                          style: TextStyle(
                            fontSize: r.sp(11),
                            fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ),
                      SizedBox(height: r.h(8)),
                      Text(
                        'Comprehensive walking pattern, balance, and movement assessment in one session',
                        style: TextStyle(
                          fontSize: r.sp(13),
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
            SizedBox(height: r.h(20)),
            // What's included badges
            Wrap(
              spacing: r.w(8),
              runSpacing: r.h(8),
              children: [
                _buildIncludeBadge(r, 'Walking'),
                _buildIncludeBadge(r, 'Turning'),
                _buildIncludeBadge(r, 'Balance'),
              ],
            ),
            SizedBox(height: r.h(20)),
            // Status or Start button
            if (isTestCompleted)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.h(14)),
                decoration: BoxDecoration(
                  color: greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(r.w(16)),
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
                      size: r.dp(20),
                    ),
                    SizedBox(width: r.w(10)),
                    Text(
                      'All Tests Completed',
                      style: TextStyle(
                        fontSize: r.sp(15),
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
                   final result = await Navigator.pushNamed(context, '/test/gait_assessment_test');

    if (result != null && result is Map<String, dynamic>) {
      setState(() => isTestCompleted = true);
      await _submitAndComplete(result);
    }
  },
  child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: r.h(16)),
                  decoration: BoxDecoration(
                    color: tealAccent,
                    borderRadius: BorderRadius.circular(r.w(16)),
                    boxShadow: [
                      BoxShadow(
                        color: tealAccent.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: r.dp(22),
                      ),
                      SizedBox(width: r.w(10)),
                      Text(
                        'Start Complete Assessment',
                        style: TextStyle(
                          fontSize: r.sp(15),
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

  Widget _buildIncludeBadge(Responsive r, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(6)),
      decoration: BoxDecoration(
        color: const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(r.w(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            color: tealAccent,
            size: r.dp(14),
          ),
          SizedBox(width: r.w(4)),
          Text(
            text,
            style: TextStyle(
              fontSize: r.sp(12),
              fontWeight: FontWeight.w600,
              color: tealAccent,
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
