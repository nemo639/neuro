import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
  int _selectedNavIndex = 4;

  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);
  static const Color blueAccent = Color(0xFF3B82F6);

  String _memberSince = "";
  int _totalTestsCompleted = 0;
  int _testsThisWeek = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    
    _loadUserData();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final result = await ApiService.getUserProfile();
    final dashResult = await ApiService.getUserDashboard();

    if (mounted) {
      setState(() {
        _isLoading = false;

        if (result['success']) {
          final data = result['data'];
          _userData = data;

          if (data['created_at'] != null) {
            final date = DateTime.parse(data['created_at']);
            _memberSince = "${_monthName(date.month)} ${date.year}";
          }
        }

        if (dashResult['success']) {
          final dash = dashResult['data'];
          _totalTestsCompleted = dash['total_tests_completed'] ?? 0;
          _testsThisWeek = dash['tests_this_week'] ?? 0;
          _streak = dash['streak'] ?? dash['wellness_streak'] ?? 0;
        }
      });
    }
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    HapticFeedback.selectionClick();
    
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
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
        setState(() => _selectedNavIndex = index);
        break;
    }
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 30),
              _buildProfileAvatar(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildPremiumCard(),
              const SizedBox(height: 24),
              _buildSettingsMenu(),
              const SizedBox(height: 20),
              _buildSignOutButton(),
              const SizedBox(height: 100),
            ],
          ),
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
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
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
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 44, height: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final firstName = _userData?['first_name'] ?? 'User';
    final lastName = _userData?['last_name'] ?? '';
    final email = _userData?['email'] ?? 'user@email.com';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U';
    final profileImagePath = _userData?['profile_image_path'];

    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: darkCard.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: (profileImagePath != null && profileImagePath.toString().isNotEmpty)
                      ? Image.network(
                          "${ApiService.baseUrl}/$profileImagePath",
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (_userData?['is_verified'] ?? false) ? blueAccent : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: bgColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: blueAccent.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$firstName $lastName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.assignment_turned_in_outlined,
                value: '$_totalTestsCompleted',
                label: 'Tests\nCompleted',
                iconBg: mintGreen,
              ),
              _buildDivider(),
              _buildStatItem(
                icon: Icons.local_fire_department_rounded,
                value: '$_streak days',
                label: 'Current\nStreak',
                iconBg: softLavender,
              ),
              _buildDivider(),
              _buildStatItem(
                icon: Icons.calendar_month_rounded,
                value: _memberSince.isNotEmpty ? _memberSince : 'N/A',
                label: 'Member\nSince',
                iconBg: creamBeige,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconBg,
  }) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: Colors.black87),
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
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.5),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 60,
      color: Colors.black.withOpacity(0.08),
    );
  }

  Widget _buildPremiumCard() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: darkCard.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: mintGreen,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Premium Member',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: mintGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Unlimited access to all features',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PremiumSubscriptionScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Manage Subscription',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildSettingsMenu() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Edit Profile',
                iconBgColor: blueAccent,
                isFirst: true,
                onTap: () {
                  Navigator.pushNamed(context, '/edit-profile');
                },
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.shield_outlined,
                title: 'Privacy & Security',
                iconBgColor: const Color(0xFFF97316),
                onTap: () => _showPrivacySheet(),
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                iconBgColor: const Color(0xFF8B5CF6),
                onTap: () => _showTermsDialog(),
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                iconBgColor: const Color(0xFF10B981),
                onTap: () => _showPrivacyPolicyDialog(),
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                iconBgColor: blueAccent,
                onTap: () => _showHelpSheet(),
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About App',
                iconBgColor: const Color(0xFF6B7280),
                isLast: true,
                onTap: () => _showAboutDialog(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Privacy & Security',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _buildPrivacyToggle(
                      Icons.visibility_off_rounded,
                      'Hide Sensitive Data',
                      'Blur test scores and results',
                      _hideSensitiveData,
                      (value) {
                        setSheetState(() => _hideSensitiveData = value);
                        setState(() {});
                        _showSettingSavedSnackbar('Sensitive data ${value ? 'hidden' : 'visible'}');
                      },
                    ),
                    _buildPrivacyToggle(
                      Icons.screenshot_rounded,
                      'Screen Security',
                      'Prevent screenshots in app',
                      _screenSecurityEnabled,
                      (value) {
                        setSheetState(() => _screenSecurityEnabled = value);
                        setState(() {});
                        _showSettingSavedSnackbar('Screen security ${value ? 'enabled' : 'disabled'}');
                      },
                    ),
                    _buildPrivacyToggle(
                      Icons.analytics_outlined,
                      'Share Analytics',
                      'Help improve the app anonymously',
                      _shareAnalytics,
                      (value) {
                        setSheetState(() => _shareAnalytics = value);
                        setState(() {});
                        _showSettingSavedSnackbar('Analytics ${value ? 'enabled' : 'disabled'}');
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildPrivacyOptionWithAction(
                      Icons.fingerprint_rounded, 
                      'Biometric Login', 
                      'Use fingerprint or face ID',
                      onTap: () => _showComingSoonDialog('Biometric Login'),
                    ),
                    _buildPrivacyOptionWithAction(
                      Icons.lock_clock_rounded, 
                      'App Lock', 
                      'Set PIN or pattern lock',
                      onTap: () => _showComingSoonDialog('App Lock'),
                    ),
                    _buildPrivacyOptionWithAction(
                      Icons.cleaning_services_rounded, 
                      'Clear Cache', 
                      'Free up storage space',
                      onTap: () => _showClearCacheDialog(),
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

  // Privacy toggle states (frontend only)
  bool _hideSensitiveData = false;
  bool _screenSecurityEnabled = false;
  bool _shareAnalytics = true;

  void _showSettingSavedSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showClearCacheDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.cleaning_services_rounded, color: blueAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Clear Cache', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'This will clear temporary files and cached images. Your account data and test results will not be affected.',
          style: TextStyle(color: Colors.black54, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.black.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performClearCache();
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _performClearCache() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Clearing cache...'),
            ],
          ),
        ),
      ),
    );

    // Simulate cache clearing
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Cache cleared successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildPrivacyToggle(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: blueAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOptionWithAction(IconData icon, String title, String subtitle, {required VoidCallback onTap, bool isDestructive = false}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFEE2E2) : bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDestructive ? Colors.white : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: isDestructive ? const Color(0xFFDC2626) : Colors.black54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? const Color(0xFFDC2626) : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDestructive ? const Color(0xFFDC2626).withOpacity(0.7) : Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDestructive ? const Color(0xFFDC2626).withOpacity(0.5) : Colors.black.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: softYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFF59E0B),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Coming Soon!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$feature will be available in the next update. Stay tuned!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.52,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Help & Support',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              _buildHelpOption(
                Icons.quiz_outlined, 
                'FAQs', 
                'Common questions answered',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FAQsScreen()));
                },
              ),
              _buildHelpOption(
                Icons.support_agent_rounded, 
                'Contact Support', 
                'Get help from our team',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactSupportScreen()));
                },
              ),
              _buildHelpOption(
                Icons.menu_book_rounded, 
                'User Guide', 
                'Learn how to use the app',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const UserGuideScreen()));
                },
              ),
              _buildHelpOption(
                Icons.feedback_outlined, 
                'Submit Feedback', 
                'Help us improve the app',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SubmitFeedbackScreen()));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpOption(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: blueAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.black.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTermsSection(
                        '1. Medical Disclaimer',
                        'NeuroVerse is a screening tool designed to assist in early detection of neurological conditions. This app does NOT provide medical diagnosis. Results should be reviewed by qualified healthcare professionals.',
                      ),
                      _buildTermsSection(
                        '2. Data Collection & Usage',
                        'We collect neurological assessment data including speech patterns, motor function measurements, cognitive test results, and digital wellness metrics. This data is encrypted using AES-256 encryption.',
                      ),
                      _buildTermsSection(
                        '3. AI & Machine Learning',
                        'Our AI models analyze your assessment data to generate risk scores. These models are trained on anonymized clinical data and are continuously improved.',
                      ),
                      _buildTermsSection(
                        '4. Research Participation',
                        'Anonymized data may be used for neurodegenerative disease research to improve detection algorithms. You can opt-out in Privacy Settings.',
                      ),
                      _buildTermsSection(
                        '5. User Responsibilities',
                        'You agree to provide accurate information, complete assessments as instructed, and use the app for its intended purpose.',
                      ),
                      _buildTermsSection(
                        '6. Limitation of Liability',
                        'NeuroVerse and its developers are not liable for any decisions made based on app results. The app is provided "as is" without warranties.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'I Understand',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTermsSection(
                        '1. Information We Collect',
                        '• Personal Information: Name, email, phone\n• Health Data: Assessment results, risk scores\n• Device Data: Device type, OS version',
                      ),
                      _buildTermsSection(
                        '2. How We Use Your Data',
                        '• Generate personalized health assessments\n• Improve AI detection algorithms\n• Send important notifications',
                      ),
                      _buildTermsSection(
                        '3. Data Storage & Security',
                        'All data is encrypted in transit (TLS 1.3) and at rest (AES-256). We use HIPAA-compliant cloud infrastructure.',
                      ),
                      _buildTermsSection(
                        '4. Data Sharing',
                        'We do NOT sell your personal data. Data may be shared with healthcare providers (with consent) and research institutions (anonymized).',
                      ),
                      _buildTermsSection(
                        '5. Your Rights',
                        '• Access your data anytime\n• Request data deletion\n• Opt-out of research participation',
                      ),
                      _buildTermsSection(
                        '6. Contact Us',
                        'For privacy concerns:\nEmail: privacy@neuroverse.pk',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(40, 40),
                    painter: BrainLogoPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'NeuroVerse',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AI-powered neurological health screening for early detection of Alzheimer\'s and Parkinson\'s disease.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.6),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required Color iconBgColor,
    String? badge,
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(24) : Radius.zero,
            bottom: isLast ? const Radius.circular(24) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconBgColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Colors.black.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Colors.black.withOpacity(0.06),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () async {
            HapticFeedback.mediumImpact();
            await ApiService.logout();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFCA5A5).withOpacity(0.5),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Color(0xFFDC2626),
                ),
                SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
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

// ==================== Premium Subscription Screen ====================
class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  String _cardType = 'unknown';
  int _selectedPlan = 1; // 0 = monthly, 1 = yearly

  @override
  void dispose() {
    _cardNumberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String _detectCardType(String number) {
    final cleanNumber = number.replaceAll(' ', '');
    if (cleanNumber.isEmpty) return 'unknown';
    
    if (cleanNumber.startsWith('4')) {
      return 'visa';
    } else if (cleanNumber.startsWith('5') || cleanNumber.startsWith('2')) {
      if (cleanNumber.length >= 2) {
        final prefix = int.tryParse(cleanNumber.substring(0, 2)) ?? 0;
        if ((prefix >= 51 && prefix <= 55) || (prefix >= 22 && prefix <= 27)) {
          return 'mastercard';
        }
      }
      return 'mastercard';
    } else if (cleanNumber.startsWith('3')) {
      if (cleanNumber.length >= 2) {
        final prefix = cleanNumber.substring(0, 2);
        if (prefix == '34' || prefix == '37') {
          return 'amex';
        }
      }
    } else if (cleanNumber.startsWith('6')) {
      return 'discover';
    }
    return 'unknown';
  }

  Widget _getCardIcon() {
    switch (_cardType) {
      case 'visa':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F71),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'VISA',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case 'mastercard':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFF79E1B).withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      case 'amex':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF006FCF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'AMEX',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        );
      case 'discover':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6600),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'DISCOVER',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 8,
            ),
          ),
        );
      default:
        return Icon(Icons.credit_card_rounded, color: Colors.black.withOpacity(0.3));
    }
  }

  String _formatCardNumber(String value) {
    final cleanValue = value.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleanValue.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleanValue[i]);
    }
    return buffer.toString();
  }

  void _showPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: mintGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.black87,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Thank You! 🙏',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please pray for us and our project!\n\nWe are working hard to bring you the best experience. Premium features will be launching in the coming months.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.6),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: softLavender.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rocket_launch_rounded, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Stay tuned for updates!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Got it!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              
              // Premium Card Preview
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A1A1A),
                        Color(0xFF2D2D2D),
                        Color(0xFF1A1A1A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: darkCard.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
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
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: mintGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.workspace_premium_rounded, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'NEUROVERSE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          _cardType != 'unknown' ? _getCardIcon() : const SizedBox(),
                        ],
                      ),
                      Text(
                        _cardNumberController.text.isEmpty 
                            ? '•••• •••• •••• ••••' 
                            : _cardNumberController.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD HOLDER',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _nameController.text.isEmpty 
                                    ? 'YOUR NAME' 
                                    : _nameController.text.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'EXPIRES',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _expiryController.text.isEmpty 
                                    ? 'MM/YY' 
                                    : _expiryController.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Plan Selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildPlanCard(0, 'Monthly', '\$9.99', '/month')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPlanCard(1, 'Yearly', '\$79.99', '/year', savings: 'Save 33%')),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Card Details Form
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _nameController,
                      label: 'Cardholder Name',
                      hint: 'Enter your name',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),
                    _buildCardNumberField(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _expiryController,
                            label: 'Expiry Date',
                            hint: 'MM/YY',
                            icon: Icons.calendar_today_rounded,
                            keyboardType: TextInputType.number,
                            maxLength: 5,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildInputField(
                            controller: _cvvController,
                            label: 'CVV',
                            hint: '•••',
                            icon: Icons.lock_outline_rounded,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            obscure: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Purchase Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showPurchaseDialog();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: blueAccent.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Purchase ${_selectedPlan == 0 ? 'Monthly' : 'Yearly'} Plan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Security Note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, size: 16, color: Colors.black.withOpacity(0.4)),
                    const SizedBox(width: 6),
                    Text(
                      'Secured by 256-bit SSL encryption',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
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
          const Text(
            'Premium Subscription',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(int index, String title, String price, String period, {String? savings}) {
    final isSelected = _selectedPlan == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedPlan = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? blueAccent.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? blueAccent : Colors.black.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (savings != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  savings,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? blueAccent : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isSelected ? blueAccent : Colors.black87,
              ),
            ),
            Text(
              period,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardNumberField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: TextField(
        controller: _cardNumberController,
        keyboardType: TextInputType.number,
        maxLength: 19,
        onChanged: (value) {
          final formatted = _formatCardNumber(value.replaceAll(' ', ''));
          if (formatted != value) {
            _cardNumberController.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }
          setState(() {
            _cardType = _detectCardType(value);
          });
        },
        decoration: InputDecoration(
          labelText: 'Card Number',
          hintText: '1234 5678 9012 3456',
          counterText: '',
          prefixIcon: const Icon(Icons.credit_card_rounded, color: Colors.black38),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _getCardIcon(),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 60),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        obscureText: obscure,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          prefixIcon: Icon(icon, color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

// ==================== FAQs Screen ====================
class FAQsScreen extends StatefulWidget {
  const FAQsScreen({super.key});

  @override
  State<FAQsScreen> createState() => _FAQsScreenState();
}

class _FAQsScreenState extends State<FAQsScreen> {
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color mintGreen = Color(0xFFB8E8D1);

  final List<Map<String, String>> _faqs = [
    {
      'question': 'What is NeuroVerse?',
      'answer': 'NeuroVerse is an AI-powered mobile application designed to screen for early signs of neurodegenerative diseases like Parkinson\'s and Alzheimer\'s. It uses advanced machine learning algorithms to analyze speech patterns, motor functions, cognitive abilities, and gait movements.'
    },
    {
      'question': 'Is NeuroVerse a medical diagnostic tool?',
      'answer': 'No, NeuroVerse is a screening tool, not a diagnostic device. It helps identify potential risk factors and early indicators that should be discussed with healthcare professionals. Always consult a qualified doctor for proper medical diagnosis.'
    },
    {
      'question': 'How accurate are the test results?',
      'answer': 'Our AI models have been trained on clinical data and achieve high accuracy rates. However, results should be considered as indicators, not definitive diagnoses. Factors like device quality, environment, and user compliance can affect results.'
    },
    {
      'question': 'How often should I take the tests?',
      'answer': 'We recommend taking comprehensive tests once a week for consistent monitoring. Regular testing helps establish your baseline and track any changes over time. Quick daily check-ins are also available for routine monitoring.'
    },
    {
      'question': 'What data does the app collect?',
      'answer': 'NeuroVerse collects voice recordings (for speech analysis), finger movement data, cognitive test responses, walking pattern data from sensors, and digital wellness metrics. All data is encrypted and stored securely.'
    },
    {
      'question': 'Is my health data secure?',
      'answer': 'Yes, we take data security very seriously. All data is encrypted using AES-256 encryption both in transit and at rest. We use HIPAA-compliant cloud infrastructure and never sell your personal health information.'
    },
    {
      'question': 'Can I delete my data?',
      'answer': 'Yes, you can request complete data deletion anytime from Privacy & Security settings. Once requested, all your personal data and test results will be permanently deleted within 30 days.'
    },
    {
      'question': 'What is XAI (Explainable AI)?',
      'answer': 'XAI is our transparency feature that shows you exactly why the AI made certain predictions. It highlights which factors contributed most to your risk scores, helping you understand your results better.'
    },
    {
      'question': 'How does the Speech Analysis test work?',
      'answer': 'The speech test analyzes various vocal biomarkers including voice tremor, pitch variations, speech rate, and pronunciation clarity. You\'ll be asked to read specific passages, sustain vowel sounds, and describe images.'
    },
    {
      'question': 'What is tested in Motor Functions?',
      'answer': 'Motor function tests assess fine motor control through tasks like finger tapping, spiral drawing, and hand movement tracking. These tests detect subtle changes in coordination, speed, and steadiness.'
    },
    {
      'question': 'How does Cognitive Assessment work?',
      'answer': 'Cognitive tests evaluate memory, attention, processing speed, and executive function through interactive games and puzzles. Tasks include word recall, pattern recognition, and problem-solving exercises.'
    },
    {
      'question': 'What does Gait Analysis measure?',
      'answer': 'Gait analysis uses your phone\'s sensors to measure walking patterns including step length, walking speed, balance, and rhythm. Changes in gait can be early indicators of neurological conditions.'
    },
    {
      'question': 'What do the risk scores mean?',
      'answer': 'Risk scores range from 0-100 and indicate the likelihood of neurological decline indicators. Low (0-30) suggests minimal risk, Moderate (31-60) warrants monitoring, High (61-80) recommends professional consultation, and Critical (81-100) suggests urgent medical attention.'
    },
    {
      'question': 'Can I share my reports with my doctor?',
      'answer': 'Yes! You can export detailed PDF reports from the Reports section. These comprehensive reports include test results, trend analysis, and XAI explanations that can help healthcare providers understand your health status.'
    },
    {
      'question': 'What is Digital Wellness tracking?',
      'answer': 'Digital Wellness monitors your screen time, sleep patterns, and physical activity. Research shows these lifestyle factors can impact neurological health. We help you maintain healthy habits that support brain health.'
    },
    {
      'question': 'Does the app work offline?',
      'answer': 'Basic test-taking works offline, but results sync when connected. Full functionality including AI analysis, report generation, and data backup requires an internet connection.'
    },
    {
      'question': 'What devices are supported?',
      'answer': 'NeuroVerse works on iOS (iPhone 8 and newer) and Android (version 8.0+) devices. Some tests require specific sensor capabilities which most modern smartphones have.'
    },
    {
      'question': 'How do I cancel my premium subscription?',
      'answer': 'You can cancel your subscription anytime through your device\'s app store (Google Play or Apple App Store) subscription settings. You\'ll retain premium access until the end of your billing period.'
    },
    {
      'question': 'Can family members use the same account?',
      'answer': 'Each person should have their own account for accurate health tracking. Test results are personalized, and mixing data from different individuals would compromise the accuracy of AI predictions.'
    },
    {
      'question': 'How do I contact support for technical issues?',
      'answer': 'You can reach our support team via Contact Support in Help & Support section. For technical issues, email tech.support@neuro.pk. Our team typically responds within 24-48 hours.'
    },
  ];

  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _faqs.length,
                itemBuilder: (context, index) => _buildFAQItem(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
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
          const Expanded(
            child: Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(int index) {
    final faq = _faqs[index];
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? blueAccent.withOpacity(0.3) : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isExpanded ? blueAccent.withOpacity(0.1) : mintGreen.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isExpanded ? blueAccent : darkCard,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      faq['question']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isExpanded ? blueAccent : Colors.black87,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isExpanded ? blueAccent : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  faq['answer']!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ==================== Contact Support Screen ====================
class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color softYellow = Color(0xFFFFF3CD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 10),
              
              _buildSectionTitle('General Support'),
              _buildContactCard(
                context,
                icon: Icons.support_agent_rounded,
                iconBg: blueAccent,
                name: 'Help Desk',
                role: 'General Inquiries & Support',
                email: 'help.desk@neuro.pk',
                description: 'For general questions, account issues, subscription queries, and basic app support.',
              ),
              
              _buildSectionTitle('Technical Support'),
              _buildContactCard(
                context,
                icon: Icons.code_rounded,
                iconBg: const Color(0xFF10B981),
                name: 'Muhammad Naeem',
                role: 'Lead Developer - Backend & AI',
                email: 'naeem.dev@neuro.pk',
                description: 'For API issues, data sync problems, AI prediction queries, and backend-related bugs.',
              ),
              _buildContactCard(
                context,
                icon: Icons.phone_android_rounded,
                iconBg: const Color(0xFF8B5CF6),
                name: 'Bilal Hassan',
                role: 'Lead Developer - Mobile & Frontend',
                email: 'bilal.dev@neuro.pk',
                description: 'For app crashes, UI/UX issues, test recording problems, and mobile app bugs.',
              ),
              
              _buildSectionTitle('Other Issues'),
              _buildContactCard(
                context,
                icon: Icons.business_center_rounded,
                iconBg: const Color(0xFFF97316),
                name: 'Haider Abbas',
                role: 'Project Coordinator',
                email: 'haider.support@neuro.pk',
                description: 'For partnership inquiries, feedback escalation, account recovery, and non-technical concerns.',
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: softYellow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEAB308).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFFEAB308),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Response Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We typically respond within 24-48 hours during business days.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withOpacity(0.6),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
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
          const Text(
            'Contact Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required String name,
    required String role,
    required String email,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: iconBg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: iconBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: email));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Email copied: $email'),
                    backgroundColor: darkCard,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconBg.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.email_outlined, size: 18, color: iconBg),
                    const SizedBox(width: 8),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: iconBg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 16, color: iconBg.withOpacity(0.7)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== User Guide Screen ====================
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  static const Color bgColor = Color(0xFFF7F7F7);

  @override
  Widget build(BuildContext context) {
    final guides = [
      {
        'icon': Icons.home_rounded,
        'title': 'Dashboard Overview',
        'color': const Color(0xFF3B82F6),
        'steps': [
          'View your overall health risk score at the top',
          'Check individual category scores',
          'See your recent test history',
          'Track your daily streak and wellness metrics',
        ],
      },
      {
        'icon': Icons.mic_rounded,
        'title': 'Taking Speech Tests',
        'color': const Color(0xFF10B981),
        'steps': [
          'Find a quiet environment',
          'Hold phone 6-8 inches from mouth',
          'Speak clearly at normal pace',
          'Follow on-screen prompts',
        ],
      },
      {
        'icon': Icons.touch_app_rounded,
        'title': 'Motor Function Tests',
        'color': const Color(0xFF8B5CF6),
        'steps': [
          'Sit comfortably with stable surface',
          'Tap alternating buttons quickly',
          'Draw spirals smoothly from center',
          'Keep wrist steady',
        ],
      },
      {
        'icon': Icons.psychology_rounded,
        'title': 'Cognitive Tests',
        'color': const Color(0xFFF97316),
        'steps': [
          'Take tests when alert and focused',
          'Read instructions carefully',
          'Pay attention during learning phase',
          'Don\'t rush - accuracy matters',
        ],
      },
      {
        'icon': Icons.directions_walk_rounded,
        'title': 'Gait Analysis',
        'color': const Color(0xFFEF4444),
        'steps': [
          'Place phone in pocket or hold at waist',
          'Walk in clear straight path',
          'Walk at normal comfortable pace',
          'Avoid holding objects while walking',
        ],
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'Understanding XAI',
        'color': const Color(0xFF6366F1),
        'steps': [
          'XAI shows factors influencing score',
          'Green = positive contributions',
          'Red = areas of concern',
          'Use insights for doctor discussions',
        ],
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withOpacity(0.08)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'User Guide',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: guides.length,
                itemBuilder: (context, index) {
                  final guide = guides[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Theme(
                      data: ThemeData().copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (guide['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(guide['icon'] as IconData, color: guide['color'] as Color),
                        ),
                        title: Text(
                          guide['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (guide['color'] as Color).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: (guide['steps'] as List<String>).asMap().entries.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: (guide['color'] as Color).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${e.key + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: guide['color'] as Color,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          e.value,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
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
      ),
    );
  }
}

// ==================== Submit Feedback Screen ====================
class SubmitFeedbackScreen extends StatefulWidget {
  const SubmitFeedbackScreen({super.key});

  @override
  State<SubmitFeedbackScreen> createState() => _SubmitFeedbackScreenState();
}

class _SubmitFeedbackScreenState extends State<SubmitFeedbackScreen> with SingleTickerProviderStateMixin {
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);

  late TabController _tabController;
  
  // Submit tab state
  final TextEditingController _feedbackController = TextEditingController();
  String _selectedCategory = 'General';
  int _rating = 0;
  bool _isSubmitting = false;

  // History tab state
  List<Map<String, dynamic>> _feedbackHistory = [];
  bool _isLoadingHistory = true;
  int _currentPage = 1;
  int _totalPages = 1;

  final List<String> _categories = ['General', 'Bug Report', 'Feature Request', 'UI/UX', 'Performance', 'Other'];

  final Map<String, String> _categoryMap = {
    'General': 'general',
    'Bug Report': 'bug_report',
    'Feature Request': 'feature_request',
    'UI/UX': 'ui_ux',
    'Performance': 'performance',
    'Other': 'other',
  };

  final Map<String, String> _reverseCategoryMap = {
    'general': 'General',
    'bug_report': 'Bug Report',
    'feature_request': 'Feature Request',
    'ui_ux': 'UI/UX',
    'performance': 'Performance',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _feedbackHistory.isEmpty) {
        _loadFeedbackHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadFeedbackHistory() async {
    setState(() => _isLoadingHistory = true);

    final result = await ApiService.getMyFeedbacks(page: _currentPage, perPage: 10);

    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (result['success'] && result['data'] != null) {
          final data = result['data'];
          _feedbackHistory = List<Map<String, dynamic>>.from(data['feedbacks'] ?? []);
          _totalPages = data['total_pages'] ?? 1;
        }
      });
    }
  }

  Future<void> _deleteFeedback(int feedbackId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Feedback?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.black.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await ApiService.deleteFeedback(feedbackId: feedbackId);
      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Feedback deleted'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          _loadFeedbackHistory();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to delete'),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  void _submitFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your feedback'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ApiService.submitFeedback(
      category: _categoryMap[_selectedCategory] ?? 'general',
      message: _feedbackController.text.trim(),
      rating: _rating > 0 ? _rating : null,
      appVersion: '1.0.0',
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thank you for your feedback!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Clear form
        _feedbackController.clear();
        setState(() {
          _rating = 0;
          _selectedCategory = 'General';
        });
        // Refresh history if already loaded
        if (_feedbackHistory.isNotEmpty) {
          _loadFeedbackHistory();
        }
        // Switch to history tab
        _tabController.animateTo(1);
        _loadFeedbackHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to submit feedback'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withOpacity(0.08)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Feedback',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Submit'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSubmitTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rate your experience', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                final isSelected = i + 1 <= _rating;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _rating = i + 1);
                  },
                  child: AnimatedScale(
                    scale: isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: isSelected ? const Color(0xFFFBBF24) : Colors.black26,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedCategory = cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? blueAccent : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? blueAccent : Colors.black12),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Your Feedback', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _feedbackController,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Tell us what you think...',
                hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _isSubmitting ? null : _submitFeedback,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _isSubmitting ? Colors.black38 : darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSubmitting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_feedbackHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: softLavender.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.feedback_outlined, size: 40, color: Colors.black.withOpacity(0.3)),
            ),
            const SizedBox(height: 20),
            Text(
              'No feedback yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your submitted feedbacks will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _tabController.animateTo(0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: blueAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Submit Feedback',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeedbackHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _feedbackHistory.length + (_currentPage < _totalPages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _feedbackHistory.length) {
            return _buildLoadMoreButton();
          }
          return _buildFeedbackCard(_feedbackHistory[index]);
        },
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final status = feedback['status'] ?? 'pending';
    final category = feedback['category'] ?? 'general';
    final rating = feedback['rating'];
    final message = feedback['message'] ?? '';
    final createdAt = feedback['created_at'];
    final feedbackId = feedback['id'];

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'resolved':
        statusColor = const Color(0xFF10B981);
        statusText = 'Resolved';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'In Progress';
        statusIcon = Icons.autorenew_rounded;
        break;
      case 'reviewed':
        statusColor = blueAccent;
        statusText = 'Reviewed';
        statusIcon = Icons.visibility_rounded;
        break;
      case 'closed':
        statusColor = Colors.grey;
        statusText = 'Closed';
        statusIcon = Icons.archive_rounded;
        break;
      default:
        statusColor = const Color(0xFFF97316);
        statusText = 'Pending';
        statusIcon = Icons.schedule_rounded;
    }

    String formattedDate = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = '${date.day}/${date.month}/${date.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _reverseCategoryMap[category] ?? category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: blueAccent,
                  ),
                ),
              ),
              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rating stars
          if (rating != null) ...[
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: i < rating ? const Color(0xFFFBBF24) : Colors.black12,
                );
              }),
            ),
            const SizedBox(height: 10),
          ],
          // Message
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.7),
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
              GestureDetector(
                onTap: () => _deleteFeedback(feedbackId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _currentPage++);
        _loadFeedbackHistory();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: const Center(
          child: Text(
            'Load More',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF3B82F6),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Brain Logo Painter ====================
class BrainLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8E8D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final leftPath = Path();
    leftPath.moveTo(centerX - 2, centerY - size.height * 0.35);
    leftPath.cubicTo(
      centerX - size.width * 0.4, centerY - size.height * 0.3,
      centerX - size.width * 0.45, centerY + size.height * 0.2,
      centerX - 2, centerY + size.height * 0.35,
    );
    canvas.drawPath(leftPath, paint);

    final rightPath = Path();
    rightPath.moveTo(centerX + 2, centerY - size.height * 0.35);
    rightPath.cubicTo(
      centerX + size.width * 0.4, centerY - size.height * 0.3,
      centerX + size.width * 0.45, centerY + size.height * 0.2,
      centerX + 2, centerY + size.height * 0.35,
    );
    canvas.drawPath(rightPath, paint);

    canvas.drawLine(
      Offset(centerX, centerY - size.height * 0.3),
      Offset(centerX, centerY + size.height * 0.3),
      paint,
    );

    paint.strokeWidth = 1.5;
    canvas.drawLine(
      Offset(centerX - size.width * 0.15, centerY - size.height * 0.1),
      Offset(centerX - size.width * 0.3, centerY - size.height * 0.15),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - size.width * 0.15, centerY + size.height * 0.1),
      Offset(centerX - size.width * 0.3, centerY + size.height * 0.15),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + size.width * 0.15, centerY - size.height * 0.1),
      Offset(centerX + size.width * 0.3, centerY - size.height * 0.15),
      paint,
    );
    canvas.drawLine(
      Offset(centerX + size.width * 0.15, centerY + size.height * 0.1),
      Offset(centerX + size.width * 0.3, centerY + size.height * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}