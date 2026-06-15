import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/responsive.dart';
import 'package:neuroverse/features/Home/home.dart';
import 'package:neuroverse/features/Labs/testsscreen.dart';
import 'package:neuroverse/features/XAI/XAI.dart';
import 'package:neuroverse/features/Chat/neuro_chat_screen.dart';
import 'package:neuroverse/features/Report/reports_screen.dart';
import 'package:neuroverse/features/Profile/profile.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => MainShellState();

  static MainShellState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainShellState>();
  }

  static void switchTab(BuildContext context, int index) {
    final shell = of(context);
    if (shell != null) {
      shell.switchTab(index);
    } else {
      // Fallback: not inside a shell yet (e.g., from login). Push a fresh shell.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainShell(initialIndex: index)),
      );
    }
  }
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  static const Color navBg = Color(0xFFFAFAFA);
  static const Color darkCard = Color(0xFF1A1A1A);

  static const List<_NavSpec> _navSpecs = [
    _NavSpec(Icons.home_rounded, 'Home'),
    _NavSpec(Icons.assignment_outlined, 'Tests'),
    _NavSpec(Icons.auto_awesome_rounded, 'XAI'),
    _NavSpec(Icons.stars_rounded, 'Neuro'),
    _NavSpec(Icons.description_outlined, 'Reports'),
    _NavSpec(Icons.person_outline_rounded, 'Profile'),
  ];

  // Lazy-built screens — built on first activation, then kept alive by IndexedStack.
  final List<Widget?> _screens = List.filled(6, null);

  Widget _buildScreen(int i) {
    switch (i) {
      case 0:
        return const HomeScreen();
      case 1:
        return const TestsScreen();
      case 2:
        return const XAIScreen();
      case 3:
        return const NeuroChatScreen();
      case 4:
        return const ReportsScreen();
      case 5:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 5);
    _screens[_currentIndex] = _buildScreen(_currentIndex);
  }

  void switchTab(int index) {
    if (index < 0 || index > 5 || index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _screens[index] ??= _buildScreen(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          6,
          (i) => _screens[i] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(r),
    );
  }

  Widget _buildBottomNav(Responsive r) {
    return Container(
      margin: EdgeInsets.fromLTRB(r.w(16), 0, r.w(16), r.h(16)),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(r.w(24)),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: r.w(20),
            offset: Offset(0, r.h(4)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navSpecs.length, (i) {
              return _buildNavItem(i, _navSpecs[i].icon, _navSpecs[i].label, r);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Responsive r) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => switchTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(10)),
        decoration: BoxDecoration(
          color: isSelected ? darkCard : Colors.transparent,
          borderRadius: BorderRadius.circular(r.w(16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black38,
              size: r.dp(22),
            ),
            if (isSelected) ...[
              SizedBox(width: r.w(8)),
              Text(
                label,
                style: TextStyle(
                  fontSize: r.sp(13),
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
}

class _NavSpec {
  final IconData icon;
  final String label;
  const _NavSpec(this.icon, this.label);
}
