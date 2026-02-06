import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with TickerProviderStateMixin {
  late AnimationController _pageController;
  late AnimationController _fabController;
  int _selectedNavIndex = 0;
  
  // State
  bool _isLoading = true;
  Map<String, dynamic> _adminData = {};
  Map<String, dynamic> _dashboardData = {};

  // ==================== MODERN ADMIN COLOR PALETTE ====================
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color deepIndigo = Color(0xFF3730A3);
  static const Color lightIndigo = Color(0xFF818CF8);
  static const Color bgGray = Color(0xFFF9FAFB);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF111827);
  static const Color textGray = Color(0xFF6B7280);
  static const Color borderGray = Color(0xFFE5E7EB);
  
  // Accent Colors
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFE11D48);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentCyan = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
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
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final result = await ApiService.getAdminDashboard();
      
      if (mounted) {
        if (result['success']) {
          setState(() {
            _dashboardData = result['data'];
            _adminData = result['data']['admin'] ?? {};
            _isLoading = false;
          });
        } else {
          // Fallback to mock data
          _loadMockData();
        }
      }
    } catch (e) {
      if (mounted) {
        _loadMockData();
      }
    }
  }

  void _loadMockData() {
    setState(() {
      _isLoading = false;
      _adminData = {
        'first_name': 'Super',
        'last_name': 'Admin',
        'email': 'admin@neuroverse.com',
        'role': 'super_admin',
        'profile_image_path': null,
      };
      _dashboardData = {
        'total_users': 1248,
        'total_doctors': 24,
        'pending_verifications': 5,
        'open_tickets': 18,
        'dataset_requests': 3,
        'recent_activities': [
          {'action': 'Doctor Verified', 'details': 'Dr. Ahmad Khan approved', 'time': '2m', 'type': 'success'},
          {'action': 'Support Ticket', 'details': 'Login issue reported', 'time': '15m', 'type': 'warning'},
          {'action': 'User Registered', 'details': 'New patient signup', 'time': '1h', 'type': 'info'},
          {'action': 'Dataset Request', 'details': 'Research request pending', 'time': '3h', 'type': 'pending'},
        ],
        'pending_tickets': [
          {'id': 'TKT-001', 'subject': 'Cannot access test results', 'user': 'Fatima Ali', 'priority': 'High', 'category': 'Technical'},
          {'id': 'TKT-002', 'subject': 'Password reset not working', 'user': 'Hassan Khan', 'priority': 'Medium', 'category': 'Account'},
          {'id': 'TKT-003', 'subject': 'App crashing on reports', 'user': 'Zara Ahmed', 'priority': 'High', 'category': 'Bug'},
        ],
      };
    });
  }

  String get adminName => '${_adminData['first_name'] ?? 'Admin'} ${_adminData['last_name'] ?? ''}';
  String get adminEmail => _adminData['email'] ?? 'admin@neuroverse.com';
  String get adminRole => _formatRole(_adminData['role'] ?? 'admin');

  String _formatRole(String role) {
    return role.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  void _onNavItemTapped(int index) {
    HapticFeedback.selectionClick();
    
    if (index == _selectedNavIndex) return;
    
    setState(() => _selectedNavIndex = index);
    
    switch (index) {
      case 0: // Dashboard
        break;
      case 1: // Users
        Navigator.pushNamed(context, '/admin-users');
        break;
      case 2: // Support
        Navigator.pushNamed(context, '/admin-support');
        break;
      case 3: // Analytics
        Navigator.pushNamed(context, '/admin-analytics');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 48,
                  color: primaryIndigo,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: primaryIndigo,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading Admin Panel...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textGray,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: bgGray,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: primaryIndigo,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildStatsOverview(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildPrioritySection(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: _buildModernNavBar(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryIndigo,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [deepIndigo, primaryIndigo, lightIndigo.withOpacity(0.8)],
            ),
          ),
          child: Stack(
            children: [
              // Animated background pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Avatar
                    Hero(
                      tag: 'admin_avatar',
                      child: GestureDetector(
                        onTap: () => _showProfileSheet(),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [accentCyan, accentBlue],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              adminName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Admin Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              adminRole,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification Icon
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/admin-notifications');
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            if ((_dashboardData['open_tickets'] ?? 0) > 0)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [accentRose, Color(0xFFFB7185)],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: primaryIndigo, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_dashboardData['open_tickets'] > 9 ? '9+' : _dashboardData['open_tickets']}',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
          children: [
            _buildModernStatCard(
              icon: Icons.people_rounded,
              label: 'Total Users',
              value: _dashboardData['total_users']?.toString() ?? '0',
              change: '+12.5%',
              isPositive: true,
              gradient: const LinearGradient(colors: [accentBlue, Color(0xFF60A5FA)]),
            ),
            _buildModernStatCard(
              icon: Icons.medical_services_rounded,
              label: 'Doctors',
              value: _dashboardData['total_doctors']?.toString() ?? '0',
              change: '+8.2%',
              isPositive: true,
              gradient: const LinearGradient(colors: [accentEmerald, Color(0xFF34D399)]),
            ),
            _buildModernStatCard(
              icon: Icons.pending_actions_rounded,
              label: 'Pending',
              value: _dashboardData['pending_verifications']?.toString() ?? '0',
              change: 'Needs attention',
              isPositive: false,
              gradient: const LinearGradient(colors: [accentAmber, Color(0xFFFBBF24)]),
            ),
            _buildModernStatCard(
              icon: Icons.support_agent_rounded,
              label: 'Open Tickets',
              value: _dashboardData['open_tickets']?.toString() ?? '0',
              change: '3 urgent',
              isPositive: false,
              gradient: const LinearGradient(colors: [accentRose, Color(0xFFFB7185)]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String change,
    required bool isPositive,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? accentEmerald.withOpacity(0.1)
                      : accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? accentEmerald : accentAmber,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textGray,
                ),
              ),
            ],
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildActionCard(
                  icon: Icons.person_add_rounded,
                  title: 'Verify\nDoctors',
                  gradient: const LinearGradient(colors: [primaryIndigo, deepIndigo]),
                  badge: _dashboardData['pending_verifications']?.toString() ?? '0',
                  onTap: () => Navigator.pushNamed(context, '/admin-verify-doctors'),
                ),
                _buildActionCard(
                  icon: Icons.security_rounded,
                  title: 'Manage\nPermissions',
                  gradient: const LinearGradient(colors: [accentPurple, Color(0xFFA78BFA)]),
                  badge: null,
                  onTap: () => Navigator.pushNamed(context, '/admin-permissions'),
                ),
                _buildActionCard(
                  icon: Icons.support_rounded,
                  title: 'Resolve\nTickets',
                  gradient: const LinearGradient(colors: [accentCyan, Color(0xFF22D3EE)]),
                  badge: _dashboardData['open_tickets']?.toString() ?? '0',
                  onTap: () => Navigator.pushNamed(context, '/admin-support'),
                ),
                _buildActionCard(
                  icon: Icons.analytics_rounded,
                  title: 'View\nAnalytics',
                  gradient: const LinearGradient(colors: [accentEmerald, Color(0xFF34D399)]),
                  badge: null,
                  onTap: () => Navigator.pushNamed(context, '/admin-analytics'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Gradient gradient,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _CardPatternPainter(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: Colors.white, size: 32),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Badge
            if (badge != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: gradient.colors.first,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySection() {
    final tickets = _dashboardData['pending_tickets'] as List? ?? [];
    if (tickets.isEmpty) return const SizedBox.shrink();

    return _buildAnimatedWidget(
      delay: 0.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Priority Tickets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/admin-support'),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryIndigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...tickets.take(3).map((ticket) => _buildTicketCard(ticket)),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    Color priorityColor = accentAmber;
    if (ticket['priority'] == 'High') priorityColor = accentRose;
    if (ticket['priority'] == 'Low') priorityColor = accentEmerald;

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: priorityColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket['id'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: priorityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ticket['priority'] ?? 'Medium',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: priorityColor,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGray),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket['subject'] ?? '',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline, size: 14, color: textGray),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ticket['user'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 13,
                    color: textGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryIndigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Resolve',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = _dashboardData['recent_activities'] as List? ?? [];
    if (activities.isEmpty) return const SizedBox.shrink();

    return _buildAnimatedWidget(
      delay: 0.25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(
                  activities.length,
                  (index) => _buildActivityItem(
                    activities[index],
                    isLast: index == activities.length - 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, {required bool isLast}) {
    Color typeColor = accentBlue;
    IconData typeIcon = Icons.info_rounded;

    switch (activity['type']) {
      case 'success':
        typeColor = accentEmerald;
        typeIcon = Icons.check_circle_rounded;
        break;
      case 'warning':
        typeColor = accentAmber;
        typeIcon = Icons.warning_rounded;
        break;
      case 'error':
        typeColor = accentRose;
        typeIcon = Icons.error_rounded;
        break;
      case 'pending':
        typeColor = accentPurple;
        typeIcon = Icons.pending_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: borderGray)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [typeColor, typeColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['action'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['details'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            activity['time'] ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textGray.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _fabController, curve: Curves.easeOut),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showQuickActionsMenu();
        },
        backgroundColor: primaryIndigo,
        elevation: 8,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text(
          'Quick Action',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
          _buildNavItem(1, Icons.people_rounded, 'Users'),
          _buildNavItem(2, Icons.support_rounded, 'Support'),
          _buildNavItem(3, Icons.analytics_rounded, 'Analytics'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;

    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [primaryIndigo, deepIndigo])
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryIndigo.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : textGray,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Profile Content
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accentCyan, accentBlue],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: primaryIndigo, width: 4),
              ),
              child: Center(
                child: Text(
                  adminName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              adminName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              adminEmail,
              style: const TextStyle(
                fontSize: 14,
                color: textGray,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryIndigo, deepIndigo],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                adminRole,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Profile Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildProfileAction(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile',
                    onTap: () {},
                  ),
                  _buildProfileAction(
                    icon: Icons.security_rounded,
                    title: 'Security Settings',
                    onTap: () {},
                  ),
                  _buildProfileAction(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  _buildProfileAction(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    color: accentRose,
                    onTap: () => _handleLogout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? primaryIndigo).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? primaryIndigo, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color ?? textDark,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color ?? textGray,
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickActionTile(
              icon: Icons.person_add_rounded,
              title: 'Add New User',
              subtitle: 'Create a new user account',
              color: accentBlue,
              onTap: () {},
            ),
            _buildQuickActionTile(
              icon: Icons.medical_services_rounded,
              title: 'Register Doctor',
              subtitle: 'Add doctor to the system',
              color: accentEmerald,
              onTap: () {},
            ),
            _buildQuickActionTile(
              icon: Icons.support_rounded,
              title: 'Create Ticket',
              subtitle: 'Open a new support ticket',
              color: accentCyan,
              onTap: () {},
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _handleLogout() async {
    Navigator.pop(context); // Close bottom sheet
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin-login');
      }
    }
  }

  Widget _buildAnimatedWidget({required double delay, required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _pageController,
        curve: Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
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

// Custom Painters
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 30.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.3),
      30,
      paint,
    );
    
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.7),
      20,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}