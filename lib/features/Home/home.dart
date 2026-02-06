import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pageController;
  int _selectedNavIndex = 0;
  final String userName = "Dr. Sarah";
  
  // State variables
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _wellnessData;
  String _userFirstName = 'User';
  int _adRisk = 0;
  int _pdRisk = 0;
  int _overallRisk = 0;
  String _riskLevel = 'Low';
  String _lastUpdated = '';
  double _screenTime = 0;
  double _gamingHours = 0;
  double _sleepHours = 0;
  List<dynamic> _recentTests = [];
  
  // Weekly screen time data
  List<double> _weeklyScreenTime = [6.2, 7.5, 5.8, 8.1, 6.9, 4.5, 3.2];
  
  // Design colors from reference
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadData();
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

  Future<void> _loadData() async {
    final dashResult = await ApiService.getUserDashboard();
    final wellnessResult = await ApiService.getWellnessDashboard();
    final userResult = await ApiService.getCurrentUser();

    if (mounted) {
      setState(() {
        _isLoading = false;

        if (userResult['success']) {
          _userFirstName = userResult['data']['first_name'] ?? 'User';
        }

        if (dashResult['success']) {
          _dashboardData = dashResult['data'];
          _adRisk = (_dashboardData?['ad_risk_score'] ?? 0).toInt();
          _pdRisk = (_dashboardData?['pd_risk_score'] ?? 0).toInt();
          _overallRisk = ((_adRisk + _pdRisk) / 2).toInt();
          _riskLevel = _getRiskLevel(_overallRisk);
          _recentTests = _dashboardData?['categories'] ?? [];
        }

        if (wellnessResult['success']) {
          _wellnessData = wellnessResult['data'];
          _screenTime = (_wellnessData?['today']?['screen_time_hours'] ?? 0).toDouble();
          _gamingHours = (_wellnessData?['today']?['gaming_hours'] ?? 0).toDouble();
          _sleepHours = (_wellnessData?['today']?['sleep_hours'] ?? 0).toDouble();
        }
      });
    }
  }

  String _getRiskLevel(int score) {
    if (score < 25) return 'Low';
    if (score < 50) return 'Moderate';
    if (score < 75) return 'Elevated';
    return 'High';
  }

  void _onNavItemTapped(int index) {
    HapticFeedback.selectionClick();
    
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = index);
        break;
      case 1:
        Navigator.pushNamed(context, '/tests');
        break;
      case 2:
        Navigator.pushNamed(context, '/reports');
        break;
      case 3:
        Navigator.pushNamed(context, '/XAI');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  void _showWellnessGoalsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WellnessGoalsSheet(
        currentScreenTime: _screenTime,
        currentSleepHours: _sleepHours,
        currentGamingHours: _gamingHours,
        onSave: (goals) async {
          Navigator.pop(context);
          
          // Call API to save goals
          final result = await ApiService.saveWellnessGoals(goals: goals);
          
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Goals saved successfully!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['error'] ?? 'Failed to save goals'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(),
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
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),
                    _buildMainRiskCard(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildRecentTestsSection(),
                    const SizedBox(height: 20),
                    _buildDigitalWellnessCard(),
                    const SizedBox(height: 20),
                    _buildWellnessCard(),
                    const SizedBox(height: 24),
                    _buildStartButton(),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(24, 24),
                      painter: BrainIconPainter(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NeuroVerse',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'AI Health Platform',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 22,
                          color: Colors.black87,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/profile');
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.08), width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://i.pravatar.cc/150?img=47'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return _buildAnimatedWidget(
      delay: 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Neuro Health',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.85),
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            Text(
              'Overview',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.85),
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainRiskCard() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, '/XAI');
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(28),
            ),
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
                          'Overall',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        const Text(
                          'Risk',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Assessment',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    _buildCircularIndicator(_overallRisk),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: mintGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_riskLevel Risk',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tap to view XAI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularIndicator(int value) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 3,
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(100, 100),
            painter: CircularProgressPainter(
              progress: value / 100,
              strokeWidth: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              progressColor: mintGreen,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const Text(
                      '%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Text(
                  'RISK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Alzheimer's",
                subtitle: 'Risk Score',
                value: _adRisk.toString(),
                unit: '/100',
                badge: _getRiskLevel(_adRisk),
                badgeColor: _adRisk < 25 ? const Color(0xFF059669) : const Color(0xFFEF4444),
                bgColor: mintGreen,
                icon: Icons.psychology_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatCard(
                title: "Parkinson's",
                subtitle: 'Risk Score',
                value: _pdRisk.toString(),
                unit: '/100',
                badge: _getRiskLevel(_pdRisk),
                badgeColor: _pdRisk < 25 ? const Color(0xFF059669) : const Color(0xFFEF4444),
                bgColor: softLavender,
                icon: Icons.timeline_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required String value,
    required String unit,
    required String badge,
    required Color badgeColor,
    required Color bgColor,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 22, color: Colors.black54),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTestsSection() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Tests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/tests');
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildTestCard(
                  title: 'Speech Test',
                  subtitle: 'Story recall',
                  time: '2h ago',
                  icon: Icons.mic_rounded,
                  bgColor: creamBeige,
                  isCompleted: true,
                ),
                _buildTestCard(
                  title: 'Motor Test',
                  subtitle: 'Spiral drawing',
                  time: '1d ago',
                  icon: Icons.gesture_rounded,
                  bgColor: Colors.white,
                  isCompleted: true,
                ),
                _buildTestCard(
                  title: 'Cognitive',
                  subtitle: 'Memory recall',
                  time: 'Pending',
                  icon: Icons.psychology_alt_rounded,
                  bgColor: softLavender.withOpacity(0.5),
                  isCompleted: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color bgColor,
    required bool isCompleted,
  }) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          border: bgColor == Colors.white
              ? Border.all(color: Colors.black.withOpacity(0.08))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: Colors.black87),
                ),
                if (isCompleted)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? Colors.black.withOpacity(0.4)
                        : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalWellnessCard() {
    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      softLavender.withOpacity(0.5),
                      mintGreen.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: darkCard,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Today's Screen Time",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _screenTime.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                height: 1,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'hours',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.trending_down_rounded,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 5),
                              Text(
                                '12% below limit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showWellnessGoalsDialog();
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: creamBeige,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: creamBeige.withOpacity(0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.black54,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Stats Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildWellnessStatCard(
                      icon: Icons.phone_android_rounded,
                      label: 'Screen',
                      value: _screenTime.toStringAsFixed(1),
                      bgColor: softLavender,
                      iconColor: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 10),
                    _buildWellnessStatCard(
                      icon: Icons.sports_esports_rounded,
                      label: 'Gaming',
                      value: _gamingHours.toStringAsFixed(1),
                      bgColor: const Color(0xFFFFE4E6),
                      iconColor: const Color(0xFFEC4899),
                    ),
                    const SizedBox(width: 10),
                    _buildWellnessStatCard(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: _sleepHours.toStringAsFixed(1),
                      bgColor: mintGreen,
                      iconColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
              
              // Weekly Patterns
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: darkCard.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Weekly Screen Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'This Week',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Bar Chart
                    SizedBox(
                      height: 85,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildWeeklyBar('Mon', _weeklyScreenTime[0], false),
                          _buildWeeklyBar('Tue', _weeklyScreenTime[1], false),
                          _buildWeeklyBar('Wed', _weeklyScreenTime[2], false),
                          _buildWeeklyBar('Thu', _weeklyScreenTime[3], false),
                          _buildWeeklyBar('Fri', _weeklyScreenTime[4], true),
                          _buildWeeklyBar('Sat', _weeklyScreenTime[5], false),
                          _buildWeeklyBar('Sun', _weeklyScreenTime[6], false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: mintGreen,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Screen Time (Hours)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: softLavender,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
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

  Widget _buildWellnessStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: bgColor),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBar(String day, double screenTimeHours, bool isToday) {
    // Normalize value between 0-1 for height
    final normalizedValue = (screenTimeHours / 12).clamp(0.0, 1.0);
    
    // Calculate glow intensity based on screen time
    final glowIntensity = (screenTimeHours / 8).clamp(0.0, 1.0);
    
    // Color based on screen time
    Color barColor;
    if (screenTimeHours < 4) {
      barColor = const Color(0xFF10B981); // Green
    } else if (screenTimeHours < 6) {
      barColor = const Color(0xFFFBBF24); // Yellow
    } else if (screenTimeHours < 8) {
      barColor = const Color(0xFFF59E0B); // Orange
    } else {
      barColor = const Color(0xFFEF4444); // Red
    }
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: 55 * normalizedValue,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isToday
                  ? [softLavender, softLavender.withOpacity(0.6)]
                  : [barColor, barColor.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: (isToday ? softLavender : barColor).withOpacity(0.3 + (glowIntensity * 0.5)),
                blurRadius: 8 + (glowIntensity * 15),
                spreadRadius: glowIntensity * 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildWellnessCard() {
    return _buildAnimatedWidget(
      delay: 0.35,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: softYellow,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wellness Insight',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'High screen time (8.5h). Try a break!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.black.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return _buildAnimatedWidget(
      delay: 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamed(context, '/tests');
          },
          child: Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: mintGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Start Assessment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
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

// Wellness Goals Sheet
class _WellnessGoalsSheet extends StatefulWidget {
  final double currentScreenTime;
  final double currentSleepHours;
  final double currentGamingHours;
  final Function(Map<String, double>) onSave;
  
  const _WellnessGoalsSheet({
    required this.currentScreenTime,
    required this.currentSleepHours,
    required this.currentGamingHours,
    required this.onSave,
  });
  
  @override
  State<_WellnessGoalsSheet> createState() => _WellnessGoalsSheetState();
}

class _WellnessGoalsSheetState extends State<_WellnessGoalsSheet> {
  late double _screenTimeGoal;
  late double _sleepGoal;
  late double _gamingGoal;
  
  @override
  void initState() {
    super.initState();
    _screenTimeGoal = widget.currentScreenTime > 0 ? widget.currentScreenTime : 4.0;
    _sleepGoal = widget.currentSleepHours > 0 ? widget.currentSleepHours : 8.0;
    _gamingGoal = widget.currentGamingHours > 0 ? widget.currentGamingHours : 2.0;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Set Wellness Goals',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGoalSlider(
                    label: 'Daily Screen Time Goal',
                    icon: Icons.phone_android_rounded,
                    value: _screenTimeGoal,
                    min: 1,
                    max: 12,
                    unit: 'hours',
                    color: const Color(0xFF8B5CF6),
                    onChanged: (value) => setState(() => _screenTimeGoal = value),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _buildGoalSlider(
                    label: 'Daily Sleep Goal',
                    icon: Icons.bedtime_rounded,
                    value: _sleepGoal,
                    min: 4,
                    max: 12,
                    unit: 'hours',
                    color: const Color(0xFF10B981),
                    onChanged: (value) => setState(() => _sleepGoal = value),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _buildGoalSlider(
                    label: 'Daily Gaming Limit',
                    icon: Icons.sports_esports_rounded,
                    value: _gamingGoal,
                    min: 0,
                    max: 6,
                    unit: 'hours',
                    color: const Color(0xFFEC4899),
                    onChanged: (value) => setState(() => _gamingGoal = value),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD97706)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These goals help us provide personalized wellness insights',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withOpacity(0.7),
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
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave({
                    'screen_time': _screenTimeGoal,
                    'sleep': _sleepGoal,
                    'gaming': _gamingGoal,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Save Goals',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGoalSlider({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// Custom Painters
class BrainIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.cubicTo(
      size.width * 0.25, size.height * 0.1,
      size.width * 0.08, size.height * 0.35,
      size.width * 0.12, size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.08, size.height * 0.75,
      size.width * 0.25, size.height * 0.9,
      size.width * 0.5, size.height * 0.85,
    );
    
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.cubicTo(
      size.width * 0.75, size.height * 0.1,
      size.width * 0.92, size.height * 0.35,
      size.width * 0.88, size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.92, size.height * 0.75,
      size.width * 0.75, size.height * 0.9,
      size.width * 0.5, size.height * 0.85,
    );
    
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.lineTo(size.width * 0.5, size.height * 0.85);
    
    path.moveTo(size.width * 0.2, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.4,
      size.width * 0.3, size.height * 0.55,
    );
    
    path.moveTo(size.width * 0.22, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.38, size.height * 0.62,
      size.width * 0.35, size.height * 0.75,
    );
    
    path.moveTo(size.width * 0.8, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.65, size.height * 0.4,
      size.width * 0.7, size.height * 0.55,
    );
    
    path.moveTo(size.width * 0.78, size.height * 0.6);
    path.quadraticBezierTo(
      size.width * 0.62, size.height * 0.62,
      size.width * 0.65, size.height * 0.75,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
    final radius = (size.width - strokeWidth) / 2 - 4;

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