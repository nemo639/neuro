import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});

  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> with TickerProviderStateMixin {
  bool _showPassword = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  
  String? _emailError;
  String? _passwordError;

  // ==================== CLINICAL COLOR PALETTE ====================
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color softTeal = Color(0xFFCCFBF1);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color softCyan = Color(0xFFCFFAFE);
  static const Color softSlate = Color(0xFFE2E8F0);
  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);

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
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    email = email.trim().toLowerCase();
    
    if (email.isEmpty) {
      setState(() => _emailError = "Email is required");
      return false;
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = "Please enter a valid email");
      return false;
    }
    
    setState(() => _emailError = null);
    return true;
  }

  bool _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => _passwordError = "Password is required");
      return false;
    }
    if (password.length < 6) {
      setState(() => _passwordError = "Password must be at least 6 characters");
      return false;
    }
    setState(() => _passwordError = null);
    return true;
  }

  Future<void> _handleLogin() async {
    HapticFeedback.mediumImpact();
    
    final isEmailValid = _validateEmail(_emailController.text);
    final isPasswordValid = _validatePassword(_passwordController.text);
    
    if (!isEmailValid || !isPasswordValid) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.doctorLogin(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      setState(() => _isLoading = false);
      
      if (result['success']) {
        HapticFeedback.heavyImpact();
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/doctor-home');
        }
      } else {
        _showError(result['error'] ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  void _showForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ForgotPasswordSheet(
        onSuccess: (email) {
          Navigator.pop(context);
          _showResetPasswordSheet(email);
        },
      ),
    );
  }

  void _showResetPasswordSheet(String email) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResetPasswordSheet(
        email: email,
        onSuccess: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Password reset successfully!'),
                ],
              ),
              backgroundColor: successGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
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
                    const SizedBox(height: 16),
                    _buildForgotPassword(),
                    const SizedBox(height: 24),
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
        // Top right floating circle - Teal
        Positioned(
          top: -100,
          right: -80,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_floatingController.value * math.pi) * 20,
                  _floatingController.value * 30,
                ),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        softTeal,
                        softTeal.withOpacity(0.3),
                        softTeal.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom left floating circle - Cyan
        Positioned(
          bottom: -120,
          left: -80,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -math.cos(_floatingController.value * math.pi) * 25,
                  -_floatingController.value * 40,
                ),
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        softCyan,
                        softCyan.withOpacity(0.3),
                        softCyan.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Center floating element
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          right: -50,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.cos(_floatingController.value * math.pi * 2) * 15,
                  math.sin(_floatingController.value * math.pi) * 20,
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        softSlate.withOpacity(0.5),
                        softSlate.withOpacity(0.0),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: primaryTeal.withOpacity(0.25 + _pulseController.value * 0.15),
                    blurRadius: 30 + _pulseController.value * 15,
                    spreadRadius: _pulseController.value * 5,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Medical cross
                  Icon(
                    Icons.local_hospital_rounded,
                    size: 48,
                    color: primaryTeal,
                  ),
                  // Stethoscope overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: primaryTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
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
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: softTeal,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryTeal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_rounded, size: 14, color: primaryTeal),
                const SizedBox(width: 6),
                Text(
                  'Doctor Portal',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryTeal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Welcome Back,\nDoctor",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.15,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Sign in to access patient records and diagnostics",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.5),
              height: 1.4,
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
          border: Border.all(color: Colors.black.withOpacity(0.04)),
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
            _buildInputLabel('Email Address'),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _emailController,
              focusNode: _emailFocus,
              hintText: 'doctor@neuroverse.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              error: _emailError,
              onChanged: (v) {
                if (_emailError != null) _validateEmail(v);
              },
            ),
            if (_emailError != null) _buildErrorText(_emailError!),
            
            const SizedBox(height: 20),
            
            // Password Field
            _buildInputLabel('Password'),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              hintText: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: !_showPassword,
              error: _passwordError,
              onChanged: (v) {
                if (_passwordError != null) _validatePassword(v);
              },
              suffixIcon: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showPassword = !_showPassword);
                },
                child: Icon(
                  _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.black.withOpacity(0.4),
                  size: 22,
                ),
              ),
            ),
            if (_passwordError != null) _buildErrorText(_passwordError!),
            
            const SizedBox(height: 18),
            
            // Remember Me
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _rememberMe = !_rememberMe);
              },
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _rememberMe ? primaryTeal : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _rememberMe ? primaryTeal : Colors.black.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: _rememberMe
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.6),
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

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black.withOpacity(0.5),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? error,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error != null
              ? errorRed.withOpacity(0.5)
              : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.25),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: error != null ? errorRed : primaryTeal.withOpacity(0.7),
            size: 22,
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: errorRed),
          const SizedBox(width: 6),
          Text(
            error,
            style: TextStyle(color: errorRed, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showForgotPasswordSheet();
          },
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryTeal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: GestureDetector(
        onTap: _isLoading ? null : _handleLogin,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: darkCard.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryTeal),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Sign In to Portal",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryTeal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: primaryTeal,
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
      delay: 0.3,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: softTeal.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryTeal.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryTeal.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.shield_rounded, color: primaryTeal, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Secure Clinical Access",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "HIPAA compliant • All actions are logged",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

// ==================== FORGOT PASSWORD SHEET ====================
class _ForgotPasswordSheet extends StatefulWidget {
  final Function(String email) onSuccess;
  
  const _ForgotPasswordSheet({required this.onSuccess});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color softTeal = Color(0xFFCCFBF1);
  static const Color errorRed = Color(0xFFEF4444);

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final result = await ApiService.doctorForgotPassword(email: email);
      
      setState(() => _isLoading = false);
      
      if (result['success']) {
        widget.onSuccess(email);
      } else {
        setState(() => _error = result['error'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Connection error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: softTeal,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.lock_reset_rounded, size: 40, color: primaryTeal),
                ),
              ),
              const SizedBox(height: 24),
              
              const Center(
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Enter your email to receive a verification code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              
              // Email Input
              Text(
                'Email Address',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _error != null ? errorRed.withOpacity(0.5) : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'doctor@neuroverse.com',
                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.25)),
                    prefixIcon: Icon(Icons.email_outlined, color: primaryTeal, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              
              if (_error != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 14, color: errorRed),
                    const SizedBox(width: 6),
                    Text(
                      _error!,
                      style: TextStyle(fontSize: 12, color: errorRed, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Send Button
              GestureDetector(
                onTap: _isLoading ? null : _sendOTP,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: primaryTeal, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Send Verification Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Back to Login
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTeal,
                    ),
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
}

// ==================== RESET PASSWORD SHEET ====================
class _ResetPasswordSheet extends StatefulWidget {
  final String email;
  final VoidCallback onSuccess;
  
  const _ResetPasswordSheet({required this.email, required this.onSuccess});

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;
  int _resendTimer = 60;
  bool _canResend = false;

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color softTeal = Color(0xFFCCFBF1);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
        }
      });
      return _resendTimer > 0;
    });
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  bool get _isPasswordValid {
    final password = _passwordController.text;
    return password.length >= 8 &&
           password.contains(RegExp(r'[A-Z]')) &&
           password.contains(RegExp(r'[a-z]')) &&
           password.contains(RegExp(r'[0-9]'));
  }

  Future<void> _resetPassword() async {
    final otp = _otp;
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    
    if (otp.length != 6) {
      setState(() => _error = 'Please enter complete OTP');
      return;
    }
    
    if (!_isPasswordValid) {
      setState(() => _error = 'Password must be 8+ chars with uppercase, lowercase & number');
      return;
    }
    
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final result = await ApiService.doctorResetPassword(
        email: widget.email,
        otp: otp,
        newPassword: password,
      );
      
      setState(() => _isLoading = false);
      
      if (result['success']) {
        widget.onSuccess();
      } else {
        setState(() => _error = result['error'] ?? 'Reset failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Connection error. Please try again.';
      });
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    
    setState(() {
      _canResend = false;
      _resendTimer = 60;
    });
    
    _startResendTimer();
    
    await ApiService.doctorForgotPassword(email: widget.email);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('OTP sent successfully!'),
        backgroundColor: successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Step indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: softTeal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: primaryTeal),
                      const SizedBox(width: 6),
                      Text(
                        'Step 2 of 2',
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
            const SizedBox(height: 20),
            
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the code sent to ${widget.email}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 28),
            
            // OTP Fields
            Text(
              'Verification Code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _buildOTPField(index)),
            ),
            const SizedBox(height: 16),
            
            // Resend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive code? ",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                GestureDetector(
                  onTap: _canResend ? _resendOTP : null,
                  child: Text(
                    _canResend ? 'Resend' : 'Resend in ${_resendTimer}s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _canResend ? primaryTeal : Colors.black38,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            
            // New Password
            Text(
              'New Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _passwordController,
              hint: 'Enter new password',
              showPassword: _showPassword,
              onToggle: () => setState(() => _showPassword = !_showPassword),
            ),
            const SizedBox(height: 12),
            
            // Password Requirements
            _buildRequirement('At least 8 characters', _passwordController.text.length >= 8),
            _buildRequirement('Uppercase letter', _passwordController.text.contains(RegExp(r'[A-Z]'))),
            _buildRequirement('Lowercase letter', _passwordController.text.contains(RegExp(r'[a-z]'))),
            _buildRequirement('Number', _passwordController.text.contains(RegExp(r'[0-9]'))),
            
            const SizedBox(height: 20),
            
            // Confirm Password
            Text(
              'Confirm Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 10),
            _buildPasswordField(
              controller: _confirmController,
              hint: 'Confirm new password',
              showPassword: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: errorRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 18, color: errorRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13, color: errorRed, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 28),
            
            // Reset Button
            GestureDetector(
              onTap: _isLoading ? null : _resetPassword,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: primaryTeal, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Reset Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPField(int index) {
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _otpControllers[index].text.isNotEmpty
              ? primaryTeal
              : Colors.black.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {});
          if (value.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        obscureText: !showPassword,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.25)),
          prefixIcon: Icon(Icons.lock_outline, color: primaryTeal, size: 22),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.black38,
              size: 22,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? successGreen : Colors.black26,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: met ? successGreen : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}