import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> with TickerProviderStateMixin {
  late AnimationController _pageController;
  int _selectedNavIndex = 0;
  
  // State
  bool _isLoading = true;
  String _doctorName = 'Doctor';
  String _specialization = 'Neurologist';
  int _totalPatients = 0;
  int _pendingReviews = 0;
  int _criticalAlerts = 0;
  int _notesThisWeek = 0;
  List<dynamic> _recentPatients = [];
  List<dynamic> _pendingDiagnostics = [];

  // ==================== CLINICAL COLOR PALETTE ====================
  // Professional, Clean, Medical
  static const Color bgColor = Color(0xFFF8FAFC);           // Cool gray background
  static const Color darkCard = Color(0xFF0F172A);          // Slate 900
  static const Color primaryTeal = Color(0xFF0D9488);       // Teal 600
  static const Color softTeal = Color(0xFFCCFBF1);          // Teal 100
  static const Color softSlate = Color(0xFFE2E8F0);         // Slate 200
  static const Color coolGray = Color(0xFFF1F5F9);          // Slate 100
  static const Color accentCyan = Color(0xFF06B6D4);        // Cyan 500
  static const Color softCyan = Color(0xFFCFFAFE);          // Cyan 100
  static const Color warmAmber = Color(0xFFFEF3C7);         // Amber 100
  static const Color alertRed = Color(0xFFFEE2E2);          // Red 100
  static const Color successGreen = Color(0xFF10B981);      // Emerald 500
  static const Color warningAmber = Color(0xFFF59E0B);      // Amber 500
  static const Color errorRed = Color(0xFFEF4444);          // Red 500
  static const Color navBg = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    
    _loadDashboardData();
    
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

  Future<void> _loadDashboardData() async {
    // Load from API - replace with actual calls
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        _doctorName = 'Dr. Ahmad Khan';
        _specialization = 'Neurologist';
        _totalPatients = 156;
        _pendingReviews = 8;
        _criticalAlerts = 3;
        _notesThisWeek = 24;
        
        _recentPatients = [
          {'name': 'Fatima Ali', 'age': 67, 'risk': 'High', 'lastTest': '2h ago', 'adRisk': 72, 'pdRisk': 45},
          {'name': 'Hassan Ahmed', 'age': 54, 'risk': 'Moderate', 'lastTest': '5h ago', 'adRisk': 38, 'pdRisk': 52},
          {'name': 'Zara Khan', 'age': 71, 'risk': 'Low', 'lastTest': '1d ago', 'adRisk': 15, 'pdRisk': 22},
        ];
        
        _pendingDiagnostics = [
          {'patient': 'Fatima Ali', 'test': 'Cognitive Assessment', 'time': '2h ago', 'urgent': true},
          {'patient': 'Ahmed Raza', 'test': 'Motor Function Test', 'time': '4h ago', 'urgent': false},
          {'patient': 'Sara Malik', 'test': 'Speech Analysis', 'time': '6h ago', 'urgent': true},
        ];
      });
    }
  }

  void _onNavItemTapped(int index) {
    HapticFeedback.selectionClick();
    
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = index);
        break;
      case 1:
        Navigator.pushNamed(context, '/doctor-patients');
        break;
      case 2:
        Navigator.pushNamed(context, '/doctor-reports');
        break;
      case 3:
        Navigator.pushNamed(context, '/doctor-notes');
        break;
      case 4:
        Navigator.pushNamed(context, '/doctor-profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: softTeal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.medical_services_rounded, size: 48, color: primaryTeal),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: primaryTeal,
                  strokeWidth: 3,
                ),
              ),
            ],
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
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildPendingReviews(),
                    const SizedBox(height: 24),
                    _buildRecentPatients(),
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
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_hospital_rounded,
                      color: primaryTeal,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NeuroVerse',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: softTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Doctor Portal',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                // Alerts Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/doctor-alerts');
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(Icons.notifications_none_rounded, size: 24, color: Colors.black87),
                        ),
                        if (_criticalAlerts > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: errorRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '$_criticalAlerts',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Profile
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/doctor-profile');
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryTeal, width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://i.pravatar.cc/150?img=12'),
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

  Widget _buildWelcomeCard() {
    return _buildAnimatedWidget(
      delay: 0.05,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: darkCard.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_getGreeting()},',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _doctorName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryTeal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primaryTeal.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: primaryTeal),
                              const SizedBox(width: 6),
                              Text(
                                _specialization,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Circular Progress
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 3),
                    ),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(90, 90),
                          painter: CircularProgressPainter(
                            progress: _pendingReviews / 20,
                            strokeWidth: 5,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            progressColor: primaryTeal,
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$_pendingReviews',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: warningAmber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.priority_high_rounded, size: 18, color: warningAmber),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$_criticalAlerts critical alerts • $_pendingReviews reviews pending',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.people_rounded,
                label: 'Total Patients',
                value: '$_totalPatients',
                trend: '+12 this week',
                trendPositive: true,
                bgColor: softTeal,
                iconColor: primaryTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.edit_note_rounded,
                label: 'Notes Created',
                value: '$_notesThisWeek',
                trend: 'This week',
                trendPositive: true,
                bgColor: softCyan,
                iconColor: accentCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String trend,
    required bool trendPositive,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
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
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      trendPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 12,
                      color: trendPositive ? successGreen : errorRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildQuickActionCard(
                  icon: Icons.people_alt_rounded,
                  label: 'Browse\nPatients',
                  bgColor: Colors.white,
                  iconColor: darkCard,
                  onTap: () => Navigator.pushNamed(context, '/doctor-patients'),
                ),
                _buildQuickActionCard(
                  icon: Icons.analytics_rounded,
                  label: 'Analyze\nReports',
                  bgColor: softTeal,
                  iconColor: primaryTeal,
                  onTap: () => Navigator.pushNamed(context, '/doctor-reports'),
                ),
                _buildQuickActionCard(
                  icon: Icons.note_add_rounded,
                  label: 'Clinical\nNotes',
                  bgColor: softCyan,
                  iconColor: accentCyan,
                  onTap: () => Navigator.pushNamed(context, '/doctor-notes'),
                ),
                _buildQuickActionCard(
                  icon: Icons.file_download_rounded,
                  label: 'Export\nData',
                  bgColor: warmAmber,
                  iconColor: warningAmber,
                  onTap: () {},
                ),
                _buildQuickActionCard(
                  icon: Icons.dataset_rounded,
                  label: 'Request\nDataset',
                  bgColor: alertRed,
                  iconColor: errorRed,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: bgColor == Colors.white
              ? Border.all(color: Colors.black.withOpacity(0.08))
              : null,
          boxShadow: [
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor == Colors.white ? softSlate : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingReviews() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending Reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryTeal),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...List.generate(_pendingDiagnostics.length, (index) {
              final item = _pendingDiagnostics[index];
              return _buildPendingReviewCard(
                patient: item['patient'],
                test: item['test'],
                time: item['time'],
                isUrgent: item['urgent'],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingReviewCard({
    required String patient,
    required String test,
    required String time,
    required bool isUrgent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUrgent ? errorRed.withOpacity(0.3) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUrgent ? alertRed : softSlate,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.assignment_rounded,
              color: isUrgent ? errorRed : Colors.black54,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      patient,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: alertRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: errorRed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  test,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Review',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPatients() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Patients',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/doctor-patients'),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryTeal),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _recentPatients.length,
              itemBuilder: (context, index) {
                final patient = _recentPatients[index];
                return _buildPatientCard(
                  name: patient['name'],
                  age: patient['age'],
                  risk: patient['risk'],
                  lastTest: patient['lastTest'],
                  adRisk: patient['adRisk'],
                  pdRisk: patient['pdRisk'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard({
  required String name,
  required int age,
  required String risk,
  required String lastTest,
  required int adRisk,
  required int pdRisk,
}) {
  Color riskColor = successGreen;
  Color riskBg = softTeal;
  if (risk == 'Moderate') {
    riskColor = warningAmber;
    riskBg = warmAmber;
  } else if (risk == 'High') {
    riskColor = errorRed;
    riskBg = alertRed;
  }

  return GestureDetector(
    onTap: () => HapticFeedback.lightImpact(),
    child: Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: softSlate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.split(' ').map((e) => e[0]).take(2).join(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: darkCard,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  risk,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'Age: $age • $lastTest',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                    Text(
                      '$adRisk%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: adRisk > 50 ? errorRed : darkCard,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.black.withOpacity(0.1),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                    Text(
                      '$pdRisk%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: pdRisk > 50 ? errorRed : darkCard,
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
              _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
              _buildNavItem(1, Icons.people_rounded, 'Patients'),
              _buildNavItem(2, Icons.analytics_rounded, 'Reports'),
              _buildNavItem(3, Icons.note_alt_rounded, 'Notes'),
              _buildNavItem(4, Icons.person_rounded, 'Profile'),
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
      behavior: HitTestBehavior.opaque,
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
              color: isSelected ? primaryTeal : Colors.black38,
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
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