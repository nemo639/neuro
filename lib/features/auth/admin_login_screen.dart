import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with TickerProviderStateMixin {
  bool showPassword = false;
  bool isLoading = false;
  
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  
  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  
  String? emailError;
  String? passwordError;

  // ==================== ADMIN PORTAL COLOR PALETTE ====================
  // Authoritative, Secure, Professional
  static const Color bgColor = Color(0xFFF5F3FF);           // Light violet bg
  static const Color primaryPurple = Color(0xFF7C3AED);     // Primary - Violet
  static const Color deepPurple = Color(0xFF6D28D9);        // Secondary - Deep Violet
  static const Color darkIndigo = Color(0xFF1E1B4B);        // Dark cards - Indigo
  static const Color softPurple = Color(0xFFEDE9FE);        // Light purple background
  static const Color softIndigo = Color(0xFFE0E7FF);        // Light indigo background
  static const Color warmGray = Color(0xFFF1F5F9);          // Warm gray
  static const Color accentAmber = Color(0xFFF59E0B);       // Warning/Highlight
  static const Color successGreen = Color(0xFF10B981);      // Success
  static const Color errorRed = Color(0xFFEF4444);          // Error

  @override
  void initState() {
    super.initState();
    
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _pageController.dispose();
    _pulseController.dispose();
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    email = email.trim().toLowerCase();
    
    if (email.isEmpty) {
      setState(() => emailError = "Email is required");
      return false;
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => emailError = "Please enter a valid email");
      return false;
    }
    
    setState(() => emailError = null);
    return true;
  }

  bool _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => passwordError = "Password is required");
      return false;
    }
    if (password.length < 6) {
      setState(() => passwordError = "Password must be at least 6 characters");
      return false;
    }
    setState(() => passwordError = null);
    return true;
  }

  Future<void> _handleLogin() async {
    HapticFeedback.mediumImpact();
    
    final isEmailValid = _validateEmail(emailController.text);
    final isPasswordValid = _validatePassword(passwordController.text);
    
    if (!isEmailValid || !isPasswordValid) return;
    
    setState(() => isLoading = true);
    
    try {
      final result = await ApiService.adminLogin(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      
      setState(() => isLoading = false);
      
      if (result['success']) {
        HapticFeedback.heavyImpact();
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/admin-home');
        }
      } else {
        _showError(result['error'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Connection error. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildBackButton(),
                    const SizedBox(height: 30),
                    _buildLogo(),
                    const SizedBox(height: 30),
                    _buildWelcomeText(),
                    const SizedBox(height: 32),
                    _buildLoginForm(),
                    const SizedBox(height: 28),
                    _buildLoginButton(),
                    const SizedBox(height: 32),
                    _buildSecurityNote(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Top right circle - Purple
        Positioned(
          top: -80,
          right: -60,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_floatingController.value * math.pi) * 15,
                  _floatingController.value * 25,
                ),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        softPurple,
                        softPurple.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom left circle - Indigo
        Positioned(
          bottom: -100,
          left: -50,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -math.cos(_floatingController.value * math.pi) * 20,
                  -_floatingController.value * 35,
                ),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        softIndigo,
                        softIndigo.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: GestureDetector(
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
    );
  }

  Widget _buildLogo() {
    return _buildAnimatedWidget(
      delay: 0.05,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: darkIndigo,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: primaryPurple.withOpacity(0.3 + _pulseController.value * 0.15),
                    blurRadius: 25 + _pulseController.value * 10,
                    spreadRadius: _pulseController.value * 3,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 44,
                  color: primaryPurple,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryPurple.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: primaryPurple),
                    const SizedBox(width: 6),
                    Text(
                      'Admin Portal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Administrator\nAccess",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Manage users, permissions and support requests",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email Field
            Text(
              "Admin Email",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: emailError != null
                      ? errorRed.withOpacity(0.5)
                      : Colors.black.withOpacity(0.06),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: emailController,
                focusNode: emailFocus,
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) {
                  if (emailError != null) _validateEmail(v);
                },
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "admin@neuroverse.com",
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.25),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: emailError != null ? errorRed : primaryPurple.withOpacity(0.7),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            if (emailError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: errorRed),
                  const SizedBox(width: 6),
                  Text(
                    emailError!,
                    style: TextStyle(color: errorRed, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Password Field
            Text(
              "Password",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: passwordError != null
                      ? errorRed.withOpacity(0.5)
                      : Colors.black.withOpacity(0.06),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: passwordController,
                focusNode: passwordFocus,
                obscureText: !showPassword,
                onChanged: (v) {
                  if (passwordError != null) _validatePassword(v);
                },
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "••••••••",
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.25),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    color: passwordError != null ? errorRed : primaryPurple.withOpacity(0.7),
                    size: 22,
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => showPassword = !showPassword);
                    },
                    child: Icon(
                      showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.black.withOpacity(0.4),
                      size: 22,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            if (passwordError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: errorRed),
                  const SizedBox(width: 6),
                  Text(
                    passwordError!,
                    style: TextStyle(color: errorRed, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: GestureDetector(
        onTap: isLoading ? null : _handleLogin,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [darkIndigo, darkIndigo.withOpacity(0.9)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: darkIndigo.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Access Admin Panel",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: softPurple.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryPurple.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.verified_user_rounded, color: primaryPurple, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Restricted Access",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Admin privileges only. All actions are logged.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
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
        curve: Interval(delay, math.min(delay + 0.4, 1.0), curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
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