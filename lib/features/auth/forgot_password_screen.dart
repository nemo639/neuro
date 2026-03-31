import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/loading_bars.dart';
import 'package:neuroverse/core/responsive.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final FocusNode emailFocus = FocusNode();

  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;

  String? emailError;
  bool isLoading = false;
  bool emailSent = false;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    emailFocus.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    if (email.isEmpty) {
      setState(() => emailError = "Email is required");
      return false;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.(com|org|net|edu|gov|mil|co|io|ai|pk|edu\.pk|gov\.pk|com\.pk|uk|co\.uk|de|fr|in|jp|au|ca|us|info|biz|xyz|app|dev|tech|online|site|web|cloud|email|mail|yahoo|gmail|hotmail|outlook)$',
      caseSensitive: false,
    );

    final basicEmailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');

    if (!basicEmailRegex.hasMatch(email)) {
      setState(() => emailError = "Please enter a valid email address");
      return false;
    }

    setState(() => emailError = null);
    return true;
  }

  Future<void> _handleSendResetLink() async {
    HapticFeedback.mediumImpact();

    if (_validateEmail(emailController.text.trim())) {
      setState(() => isLoading = true);

      final result = await ApiService.forgotPassword(
        email: emailController.text.trim(),
      );

      setState(() => isLoading = false);

      if (result['success']) {
        Navigator.pushNamed(
          context,
          '/reset-password',
          arguments: {
            'email': emailController.text.trim(),
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to send reset code'),
            backgroundColor: redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _handleResendEmail() {
    HapticFeedback.lightImpact();
    setState(() => emailSent = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildAnimatedBackground(r),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(r),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.w(24)),
                      child: Column(
                        children: [
                          SizedBox(height: r.h(40)),
                          _buildIcon(r),
                          SizedBox(height: r.h(32)),
                          _buildTitle(r),
                          SizedBox(height: r.h(40)),
                          emailSent ? _buildSuccessCard(r) : _buildEmailForm(r),
                          SizedBox(height: r.h(40)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(Responsive r) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -60,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_floatingController.value * math.pi) * 15,
                  _floatingController.value * 30,
                ),
                child: Container(
                  width: r.dp(250),
                  height: r.dp(250),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        emailSent ? mintGreen : softLavender,
                        (emailSent ? mintGreen : softLavender).withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: -80,
          left: -50,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -math.cos(_floatingController.value * math.pi) * 20,
                  -_floatingController.value * 40,
                ),
                child: Container(
                  width: r.dp(220),
                  height: r.dp(220),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        emailSent ? creamBeige : mintGreen,
                        (emailSent ? creamBeige : mintGreen).withOpacity(0.2),
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

  Widget _buildHeader(Responsive r) {
    return Padding(
      padding: EdgeInsets.all(r.w(20)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: r.dp(44),
              height: r.dp(44),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(r.w(14)),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: r.dp(18),
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: r.dp(100),
            height: r.dp(100),
            decoration: BoxDecoration(
              color: emailSent ? greenAccent.withOpacity(0.15) : blueAccent.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (emailSent ? greenAccent : blueAccent).withOpacity(0.2),
                  blurRadius: 30 + (_pulseController.value * 10),
                  spreadRadius: _pulseController.value * 5,
                ),
              ],
            ),
            child: Icon(
              emailSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
              size: r.dp(48),
              color: emailSent ? greenAccent : blueAccent,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        children: [
          Text(
            emailSent ? "Check Your Email" : "Forgot Password?",
            style: TextStyle(
              fontSize: r.sp(28),
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.h(12)),
          Text(
            emailSent
                ? "We've sent a password reset link to\n${emailController.text}"
                : "Don't worry! Enter your email address and we'll send you a link to reset your password.",
            style: TextStyle(
              fontSize: r.sp(15),
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.5),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Container(
        padding: EdgeInsets.all(r.w(24)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.w(28)),
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
            Text(
              "Email Address",
              style: TextStyle(
                fontSize: r.sp(13),
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            SizedBox(height: r.h(10)),
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(r.w(16)),
                border: Border.all(
                  color: emailError != null
                      ? redAccent.withOpacity(0.5)
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
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: r.sp(15),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "your.email@example.com",
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.25),
                    fontSize: r.sp(15),
                  ),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: emailError != null ? redAccent : Colors.black.withOpacity(0.4),
                    size: r.dp(22),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(16)),
                ),
              ),
            ),
            if (emailError != null) ...[
              SizedBox(height: r.h(8)),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: r.dp(14), color: redAccent),
                  SizedBox(width: r.w(6)),
                  Text(
                    emailError!,
                    style: TextStyle(
                      color: redAccent,
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: r.h(28)),
            GestureDetector(
              onTap: isLoading ? null : _handleSendResetLink,
              child: Container(
                width: double.infinity,
                height: r.h(56),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkCard, darkCard.withOpacity(0.9)],
                  ),
                  borderRadius: BorderRadius.circular(r.w(18)),
                  boxShadow: [
                    BoxShadow(
                      color: darkCard.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? LoadingBars(color: Colors.white, height: r.h(20))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: r.dp(20),
                            ),
                            SizedBox(width: r.w(10)),
                            Text(
                              "Send Reset Link",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.sp(16),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Container(
        padding: EdgeInsets.all(r.w(28)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.w(28)),
          border: Border.all(color: greenAccent.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: greenAccent.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: r.dp(70),
              height: r.dp(70),
              decoration: BoxDecoration(
                color: greenAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: r.dp(40),
                color: greenAccent,
              ),
            ),
            SizedBox(height: r.h(20)),
            Text(
              "Email Sent Successfully!",
              style: TextStyle(
                fontSize: r.sp(18),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: r.h(8)),
            Text(
              "Please check your inbox and follow the instructions to reset your password.",
              style: TextStyle(
                fontSize: r.sp(14),
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.h(28)),

            // Open Email Button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
              },
              child: Container(
                width: double.infinity,
                height: r.h(56),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [darkCard, darkCard.withOpacity(0.9)],
                  ),
                  borderRadius: BorderRadius.circular(r.w(18)),
                  boxShadow: [
                    BoxShadow(
                      color: darkCard.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_rounded, color: Colors.white, size: r.dp(20)),
                    SizedBox(width: r.w(10)),
                    Text(
                      "Open Email App",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.sp(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: r.h(16)),

            // Resend Link
            GestureDetector(
              onTap: _handleResendEmail,
              child: Container(
                width: double.infinity,
                height: r.h(56),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(r.w(18)),
                  border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: Colors.black.withOpacity(0.6),
                      size: r.dp(20),
                    ),
                    SizedBox(width: r.w(10)),
                    Text(
                      "Resend Email",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.6),
                        fontSize: r.sp(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: r.h(20)),

            // Back to login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Remember your password? ",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.5),
                    fontSize: r.sp(14),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.only(bottom: r.h(2)),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: blueAccent, width: 2)),
                    ),
                    child: Text(
                      "Sign In",
                      style: TextStyle(
                        color: blueAccent,
                        fontSize: r.sp(14),
                        fontWeight: FontWeight.w700,
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
