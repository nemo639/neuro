import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with TickerProviderStateMixin {
  // OTP Controllers
  final List<TextEditingController> otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  // Password Controllers
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmFocus = FocusNode();
  
  // Animation Controllers
  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  
  // State
  bool isLoading = false;
  bool isResending = false;
  bool resetSuccess = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;
  
  String? otpError;
  String? passwordError;
  String? confirmError;
  
  // Password strength
  double passwordStrength = 0;
  String passwordStrengthText = '';
  Color passwordStrengthColor = Colors.grey;
  
  // Timer for resend
  int resendTimer = 60;
  Timer? _timer;
  
  // Data from previous screen
  String? email;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color orangeAccent = Color(0xFFF97316);

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

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Get email from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          email = args['email'];
        });
      }
      _startResendTimer();
    });

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
    _shakeController.dispose();
    _timer?.cancel();
    for (var c in otpControllers) {
      c.dispose();
    }
    for (var f in otpFocusNodes) {
      f.dispose();
    }
    passwordController.dispose();
    confirmPasswordController.dispose();
    passwordFocus.dispose();
    confirmFocus.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => resendTimer = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer > 0) {
        setState(() => resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode => otpControllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    setState(() => otpError = null);
    
    if (value.length == 1 && index < 5) {
      otpFocusNodes[index + 1].requestFocus();
    }
    
    // Auto-focus password field when OTP complete
    if (_otpCode.length == 6) {
      passwordFocus.requestFocus();
    }
  }

  void _calculatePasswordStrength(String password) {
    double strength = 0;
    
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.1;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;
    
    setState(() {
      passwordStrength = strength.clamp(0, 1);
      if (strength < 0.3) {
        passwordStrengthText = 'Weak';
        passwordStrengthColor = redAccent;
      } else if (strength < 0.6) {
        passwordStrengthText = 'Medium';
        passwordStrengthColor = orangeAccent;
      } else if (strength < 0.8) {
        passwordStrengthText = 'Strong';
        passwordStrengthColor = blueAccent;
      } else {
        passwordStrengthText = 'Very Strong';
        passwordStrengthColor = greenAccent;
      }
    });
  }

  bool _validate() {
    bool isValid = true;
    
    // OTP validation
    if (_otpCode.length != 6) {
      setState(() => otpError = "Please enter the 6-digit code");
      isValid = false;
    } else {
      setState(() => otpError = null);
    }
    
    // Password validation
    final password = passwordController.text;
    if (password.isEmpty) {
      setState(() => passwordError = "Password is required");
      isValid = false;
    } else if (password.length < 8) {
      setState(() => passwordError = "At least 8 characters required");
      isValid = false;
    } else if (!RegExp(r'[A-Z]').hasMatch(password)) {
      setState(() => passwordError = "Include one uppercase letter");
      isValid = false;
    } else if (!RegExp(r'[a-z]').hasMatch(password)) {
      setState(() => passwordError = "Include one lowercase letter");
      isValid = false;
    } else if (!RegExp(r'[0-9]').hasMatch(password)) {
      setState(() => passwordError = "Include one number");
      isValid = false;
    } else {
      setState(() => passwordError = null);
    }
    
    // Confirm password
    if (confirmPasswordController.text.isEmpty) {
      setState(() => confirmError = "Please confirm password");
      isValid = false;
    } else if (confirmPasswordController.text != password) {
      setState(() => confirmError = "Passwords do not match");
      isValid = false;
    } else {
      setState(() => confirmError = null);
    }
    
    if (!isValid) {
      _triggerShake();
    }
    
    return isValid;
  }

  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reset());
  }

  void _clearOtp() {
    for (var c in otpControllers) {
      c.clear();
    }
    otpFocusNodes[0].requestFocus();
  }

  Future<void> _handleResetPassword() async {
    if (!_validate()) return;
    
    setState(() => isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // Call your existing API
      final result = await ApiService.resetPassword(
        email: email ?? '',
        otp: _otpCode,
        newPassword: passwordController.text,
      );

      setState(() => isLoading = false);

      if (result['success']) {
        HapticFeedback.heavyImpact();
        setState(() {
          isLoading = false;
          resetSuccess = true;
        });
        
        // Wait for animation then navigate
        await Future.delayed(const Duration(milliseconds: 2000));
        
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Password reset successfully! Please login.'),
                ],
              ),
              backgroundColor: greenAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        setState(() => isLoading = false);
        _triggerShake();
        
        // Check if it's an OTP error
        final error = result['error'] ?? 'Failed to reset password';
        if (error.toLowerCase().contains('otp') || 
            error.toLowerCase().contains('code') ||
            error.toLowerCase().contains('invalid')) {
          setState(() => otpError = error);
          _clearOtp();
        } else {
          _showError(error);
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _resendOtp() async {
    if (resendTimer > 0) return;
    
    setState(() => isResending = true);
    HapticFeedback.lightImpact();

    try {
      final result = await ApiService.forgotPassword(email: email ?? '');

      setState(() => isResending = false);

      if (result['success']) {
        _startResendTimer();
        _clearOtp();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.email_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('New code sent to your email'),
              ],
            ),
            backgroundColor: blueAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        _showError(result['error'] ?? 'Failed to resend code');
      }
    } catch (e) {
      setState(() => isResending = false);
      _showError('Failed to resend code');
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
        backgroundColor: redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildIcon(),
                          const SizedBox(height: 20),
                          _buildTitle(),
                          const SizedBox(height: 24),
                          if (!resetSuccess) ...[
                            _buildOtpSection(),
                            const SizedBox(height: 20),
                            _buildPasswordSection(),
                            const SizedBox(height: 24),
                            _buildResetButton(),
                            const SizedBox(height: 16),
                            _buildResendSection(),
                          ] else
                            _buildSuccessCard(),
                          const SizedBox(height: 40),
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

  Widget _buildAnimatedBackground() {
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
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        resetSuccess ? mintGreen : softLavender,
                        (resetSuccess ? mintGreen : softLavender).withOpacity(0.2),
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
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        resetSuccess ? creamBeige : mintGreen,
                        (resetSuccess ? creamBeige : mintGreen).withOpacity(0.2),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (!resetSuccess)
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
          const Spacer(),
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                _buildStepDot(true, 1),
                _buildStepConnector(true),
                _buildStepDot(!resetSuccess, 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(bool active, int step) {
    final bool completed = resetSuccess || (step == 1);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: completed ? greenAccent : (active ? blueAccent : Colors.grey[300]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: completed
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 12,
                  color: active ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildStepConnector(bool active) {
    return Container(
      width: 30,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: resetSuccess ? greenAccent : (active ? blueAccent : Colors.grey[300]),
    );
  }

  Widget _buildIcon() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (resetSuccess ? greenAccent : blueAccent).withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (resetSuccess ? greenAccent : blueAccent).withOpacity(0.2),
                  blurRadius: 25 + (_pulseController.value * 10),
                  spreadRadius: _pulseController.value * 5,
                ),
              ],
            ),
            child: Icon(
              resetSuccess ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
              size: 40,
              color: resetSuccess ? greenAccent : blueAccent,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        children: [
          Text(
            resetSuccess ? "Password Reset!" : "Reset Password",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (!resetSuccess)
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.5),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "Enter the code sent to "),
                  TextSpan(
                    text: email ?? 'your email',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const TextSpan(text: "\nand create a new password"),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final offset = math.sin(_shakeController.value * math.pi * 4) * 10;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: otpError != null ? redAccent.withOpacity(0.3) : Colors.black.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pin_rounded, color: blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Verification Code",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpField(index)),
              ),
              if (otpError != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: redAccent),
                    const SizedBox(width: 6),
                    Text(
                      otpError!,
                      style: const TextStyle(
                        color: redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: otpControllers[index],
        focusNode: otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: bgColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: blueAccent, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: otpError != null ? redAccent.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (value) => _onOtpChanged(index, value),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return _buildAnimatedWidget(
      delay: 0.3,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: blueAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  "New Password",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Password field
            _buildPasswordField(
              controller: passwordController,
              focusNode: passwordFocus,
              hint: "Enter new password",
              obscure: obscurePassword,
              error: passwordError,
              onToggle: () => setState(() => obscurePassword = !obscurePassword),
              onChanged: (v) {
                _calculatePasswordStrength(v);
                if (passwordError != null) setState(() => passwordError = null);
              },
            ),
            
            if (passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPasswordStrengthIndicator(),
            ],
            
            if (passwordError != null) ...[
              const SizedBox(height: 8),
              _buildErrorText(passwordError!),
            ],
            
            const SizedBox(height: 16),
            
            // Confirm password field
            _buildPasswordField(
              controller: confirmPasswordController,
              focusNode: confirmFocus,
              hint: "Confirm new password",
              obscure: obscureConfirm,
              error: confirmError,
              onToggle: () => setState(() => obscureConfirm = !obscureConfirm),
              onChanged: (v) {
                if (confirmError != null) setState(() => confirmError = null);
              },
            ),
            
            if (confirmError != null) ...[
              const SizedBox(height: 8),
              _buildErrorText(confirmError!),
            ],
            
            const SizedBox(height: 16),
            _buildPasswordRequirements(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscure,
    String? error,
    required VoidCallback onToggle,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null ? redAccent.withOpacity(0.5) : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.3),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: error != null ? redAccent : Colors.black.withOpacity(0.4),
            size: 20,
          ),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.black.withOpacity(0.4),
              size: 20,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: passwordStrength,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(passwordStrengthColor),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          passwordStrengthText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: passwordStrengthColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final password = passwordController.text;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Password must have:",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _buildRequirement("8+ chars", password.length >= 8),
              _buildRequirement("Uppercase", RegExp(r'[A-Z]').hasMatch(password)),
              _buildRequirement("Lowercase", RegExp(r'[a-z]').hasMatch(password)),
              _buildRequirement("Number", RegExp(r'[0-9]').hasMatch(password)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 14,
          color: met ? greenAccent : Colors.grey[400],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: met ? Colors.black87 : Colors.black.withOpacity(0.4),
            fontWeight: met ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorText(String error) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, size: 14, color: redAccent),
        const SizedBox(width: 6),
        Text(
          error,
          style: const TextStyle(
            color: redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return _buildAnimatedWidget(
      delay: 0.4,
      child: GestureDetector(
        onTap: isLoading ? null : _handleResetPassword,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [darkCard, darkCard.withOpacity(0.9)],
            ),
            borderRadius: BorderRadius.circular(18),
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
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(mintGreen),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "Reset Password",
                        style: TextStyle(
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
    );
  }

  Widget _buildResendSection() {
    return _buildAnimatedWidget(
      delay: 0.5,
      child: Column(
        children: [
          Text(
            "Didn't receive the code?",
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: resendTimer == 0 ? _resendOtp : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: resendTimer == 0 ? blueAccent.withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: isResending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: resendTimer == 0 ? blueAccent : Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          resendTimer > 0 ? "Resend in ${resendTimer}s" : "Resend Code",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: resendTimer == 0 ? blueAccent : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: greenAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 50,
                      color: greenAccent,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Password Changed!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Redirecting to login...",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(greenAccent),
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