import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
  int _selectedNavIndex = 4;

  bool _isLoading = true;
  Map<String, dynamic>? _doctorData;

  // Clinical color palette
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color softTeal = Color(0xFFCCFBF1);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color softCyan = Color(0xFFCFFAFE);
  static const Color softSlate = Color(0xFFE2E8F0);
  static const Color warmAmber = Color(0xFFFEF3C7);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color navBg = Color(0xFFFAFAFA);

  String _memberSince = "";
  int _totalPatientsViewed = 0;
  int _totalNotesCreated = 0;
  int _totalReportsExported = 0;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    
    _loadDoctorData();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _loadDoctorData() async {
    setState(() => _isLoading = true);

    final result = await ApiService.getDoctorProfile();

    if (mounted) {
      setState(() {
        _isLoading = false;

        if (result['success']) {
          final data = result['data'];
          _doctorData = data;

          if (data['created_at'] != null) {
            final date = DateTime.parse(data['created_at']);
            _memberSince = "${_monthName(date.month)} ${date.year}";
          }

          _totalPatientsViewed = data['total_patients_viewed'] ?? 0;
          _totalNotesCreated = data['total_notes_created'] ?? 0;
          _totalReportsExported = data['total_reports_exported'] ?? 0;
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
        Navigator.pushReplacementNamed(context, '/doctor-home');
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
        setState(() => _selectedNavIndex = index);
        break;
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.clearAuthData();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/doctor-login', (route) => false);
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: errorRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryTeal),
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
              _buildQuickInfoCard(),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: softTeal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: primaryTeal),
                      const SizedBox(width: 4),
                      Text(
                        'Doctor Portal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 46, height: 46),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final firstName = _doctorData?['first_name'] ?? 'Doctor';
    final lastName = _doctorData?['last_name'] ?? '';
    final email = _doctorData?['email'] ?? 'doctor@email.com';
    final specialization = _doctorData?['specialization'] ?? 'General';
    final hospital = _doctorData?['hospital_affiliation'] ?? '';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'D';
    final profileImagePath = _doctorData?['profile_image_path'];

    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: darkCard.withOpacity(0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: (profileImagePath != null && profileImagePath.toString().isNotEmpty)
                      ? Image.network(
                          "${ApiService.baseUrl}/$profileImagePath",
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 44,
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
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              // Verified badge
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryTeal,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bgColor, width: 3),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Dr. $firstName $lastName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: softTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatSpecialization(specialization),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primaryTeal,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (hospital.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_hospital_rounded, size: 14, color: Colors.black.withOpacity(0.4)),
                const SizedBox(width: 4),
                Text(
                  hospital,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpecialization(String spec) {
    return spec.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
            children: [
              Expanded(
                child: _buildStatItem(
                  value: '$_totalPatientsViewed',
                  label: 'Patients\nViewed',
                  icon: Icons.people_rounded,
                  color: primaryTeal,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.black.withOpacity(0.08),
              ),
              Expanded(
                child: _buildStatItem(
                  value: '$_totalNotesCreated',
                  label: 'Notes\nCreated',
                  icon: Icons.note_alt_rounded,
                  color: accentCyan,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.black.withOpacity(0.08),
              ),
              Expanded(
                child: _buildStatItem(
                  value: '$_totalReportsExported',
                  label: 'Reports\nExported',
                  icon: Icons.file_download_rounded,
                  color: warningAmber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.4),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInfoCard() {
    final licenseNumber = _doctorData?['license_number'] ?? '';
    final department = _doctorData?['department'] ?? '';
    final yearsExp = _doctorData?['years_of_experience'] ?? 0;

    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [softTeal, softCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primaryTeal.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _buildQuickInfoRow(
                icon: Icons.badge_rounded,
                label: 'License Number',
                value: licenseNumber.isNotEmpty ? licenseNumber : 'Not set',
              ),
              const SizedBox(height: 12),
              _buildQuickInfoRow(
                icon: Icons.business_rounded,
                label: 'Department',
                value: department.isNotEmpty ? department : 'Not set',
              ),
              const SizedBox(height: 12),
              _buildQuickInfoRow(
                icon: Icons.work_history_rounded,
                label: 'Experience',
                value: '$yearsExp years',
              ),
              const SizedBox(height: 12),
              _buildQuickInfoRow(
                icon: Icons.calendar_today_rounded,
                label: 'Member Since',
                value: _memberSince.isNotEmpty ? _memberSince : 'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: primaryTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
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
            children: [
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your information',
                iconBgColor: softTeal,
                iconColor: primaryTeal,
                onTap: () async {
                  final result = await Navigator.pushNamed(context, '/doctor-edit-profile');
                  if (result == true) {
                    _loadDoctorData();
                  }
                },
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                subtitle: 'Update your password',
                iconBgColor: softCyan,
                iconColor: accentCyan,
                onTap: () {
                  // Show change password dialog
                },
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.dataset_rounded,
                title: 'Dataset Requests',
                subtitle: 'View your data requests',
                iconBgColor: warmAmber,
                iconColor: warningAmber,
                onTap: () {
                  Navigator.pushNamed(context, '/doctor-dataset-requests');
                },
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.history_rounded,
                title: 'Activity Log',
                subtitle: 'View your activity history',
                iconBgColor: softSlate,
                iconColor: Colors.black54,
                onTap: () {
                  // Navigate to activity log
                },
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.help_outline_rounded,
                title: 'Help & Support',
                subtitle: 'Get help and contact us',
                iconBgColor: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF6366F1),
                onTap: () {
                  // Navigate to help
                },
              ),
              _buildMenuDivider(),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'App version and info',
                iconBgColor: softSlate,
                iconColor: Colors.black54,
                onTap: () {
                  _showAboutDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.4),
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
    );
  }

  Widget _buildMenuDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Divider(
        color: Colors.black.withOpacity(0.06),
        height: 1,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_hospital_rounded, color: primaryTeal, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NeuroVerse',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  'Doctor Portal',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAboutRow('Version', '1.0.0'),
            _buildAboutRow('Build', '2024.12.11'),
            const SizedBox(height: 12),
            Text(
              'Clinical diagnostic platform for neurological assessment with AI-powered insights.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: _handleLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: errorRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: errorRed.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: errorRed, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: errorRed,
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
        curve: Interval(delay, math.min(delay + 0.4, 1.0), curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _pageController,
          curve: Interval(delay, math.min(delay + 0.4, 1.0), curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}