import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String verificationType; // 'signup', 'forgot_password', 'login'
  
  const OTPVerificationScreen({
    super.key,
    required this.email,
    this.verificationType = 'signup',
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isLoading = false;
  bool _isVerified = false;
  bool _hasError = false;
  String? _errorMessage;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _startTimer();
    
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
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
    _timer?.cancel();
    _floatingController.dispose();
    _pageController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _otpCode {
    return _controllers.map((c) => c.text).join();
  }

  bool get _isOtpComplete {
    return _otpCode.length == 6 && _controllers.every((c) => c.text.isNotEmpty);
  }

  void _onOtpChanged(int index, String value) {
    // Clear error on input
    if (_hasError) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }

    if (value.isNotEmpty) {
      // Handle paste - distribute digits across fields
      if (value.length > 1) {
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        for (int i = 0; i < digits.length && (index + i) < 6; i++) {
          _controllers[index + i].text = digits[i];
        }
        // Focus on the last filled field or next empty field
        final lastIndex = math.min(index + digits.length - 1, 5);
        if (lastIndex < 5) {
          _focusNodes[lastIndex + 1].requestFocus();
        } else {
          _focusNodes[5].unfocus();
          // Auto verify when complete
          if (_isOtpComplete) {
            _handleVerify();
          }
        }
        return;
      }
      
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto verify when complete
        if (_isOtpComplete) {
          _handleVerify();
        }
      }
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          _focusNodes[index - 1].requestFocus();
          _controllers[index - 1].clear();
        }
      }
    }
  }

  Future<void> _handleVerify() async {
  if (!_isOtpComplete) {
    setState(() {
      _hasError = true;
      _errorMessage = "Please enter the complete 6-digit code";
    });
    _shakeController.forward().then((_) => _shakeController.reset());
    HapticFeedback.heavyImpact();
    return;
  }

  HapticFeedback.mediumImpact();
  setState(() => _isLoading = true);

  // Call API
  final result = await ApiService.verifyOtp(
    email: widget.email,
    otp: _otpCode,
  );

  if (result['success']) {
    setState(() {
      _isLoading = false;
      _isVerified = true;
    });
    
    HapticFeedback.heavyImpact();
    
    // Navigate after success animation
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      if (widget.verificationType == 'signup') {
        Navigator.pushReplacementNamed(context, '/home');
      } else if (widget.verificationType == 'forgot_password') {
        Navigator.pushReplacementNamed(
          context, 
          '/reset-password',
          arguments: {'email': widget.email, 'otp': _otpCode},
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  } else {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = result['error'] ?? "Invalid verification code. Please try again.";
    });
    _shakeController.forward().then((_) => _shakeController.reset());
    HapticFeedback.heavyImpact();
    
    // Clear OTP fields
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }
}

  Future<void> _handleResend() async {
  if (!_canResend) return;
  
  HapticFeedback.lightImpact();
  
  // Clear previous OTP
  for (var controller in _controllers) {
    controller.clear();
  }
  setState(() {
    _hasError = false;
    _errorMessage = null;
  });
  
  // Show loading
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Sending new code...',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      backgroundColor: darkCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
  
  // Call API
  final result = await ApiService.resendOtp(email: widget.email);
  
  _startTimer();
  _focusNodes[0].requestFocus();
  
  if (mounted) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result['success'] ? Icons.check_circle_rounded : Icons.error_rounded, 
              color: Colors.white, 
              size: 20
            ),
            const SizedBox(width: 12),
            Text(
              result['success'] ? 'New code sent successfully!' : (result['error'] ?? 'Failed to send code'),
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: result['success'] ? greenAccent : redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    final name = parts[0];
    final domain = parts[1];
    
    if (name.length <= 3) {
      return '${name[0]}***@$domain';
    }
    
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}@$domain';
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
                          const SizedBox(height: 30),
                          _buildIcon(),
                          const SizedBox(height: 28),
                          _buildTitle(),
                          const SizedBox(height: 40),
                          _isVerified ? _buildSuccessState() : _buildOTPForm(),
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
                        _isVerified ? mintGreen : purpleAccent.withOpacity(0.3),
                        (_isVerified ? mintGreen : purpleAccent).withOpacity(0.1),
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
                        _isVerified ? creamBeige : mintGreen,
                        (_isVerified ? creamBeige : mintGreen).withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.5,
          left: -30,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.cos(_floatingController.value * math.pi * 2) * 10,
                  math.sin(_floatingController.value * math.pi) * 15,
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        softLavender.withOpacity(0.6),
                        softLavender.withOpacity(0.1),
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
          // Timer badge
          if (!_isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _canResend ? greenAccent.withOpacity(0.15) : darkCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _canResend ? Icons.refresh_rounded : Icons.timer_outlined,
                    size: 16,
                    color: _canResend ? greenAccent : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _canResend ? "Resend" : _formattedTime,
                    style: TextStyle(
                      color: _canResend ? greenAccent : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _isVerified
                  ? greenAccent.withOpacity(0.15)
                  : _hasError
                      ? redAccent.withOpacity(0.15)
                      : blueAccent.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isVerified ? greenAccent : _hasError ? redAccent : blueAccent)
                      .withOpacity(0.2),
                  blurRadius: 30 + (_pulseController.value * 10),
                  spreadRadius: _pulseController.value * 5,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isVerified
                    ? Icons.verified_rounded
                    : _hasError
                        ? Icons.error_outline_rounded
                        : Icons.mail_outline_rounded,
                key: ValueKey(_isVerified ? 'verified' : _hasError ? 'error' : 'mail'),
                size: 48,
                color: _isVerified ? greenAccent : _hasError ? redAccent : blueAccent,
              ),
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
            _isVerified ? "Verified!" : "Verify Your Email",
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!_isVerified) ...[
            Text(
              "We've sent a 6-digit code to",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _maskEmail(widget.email),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: blueAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ] else
            Text(
              "Your email has been verified successfully!",
              style: TextStyle(
                fontSize: 15,
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

  Widget _buildOTPForm() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Column(
        children: [
          // OTP Input Fields
          AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              final shakeOffset = math.sin(_shakeController.value * math.pi * 4) * 10;
              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasError
                      ? redAccent.withOpacity(0.3)
                      : Colors.black.withOpacity(0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _hasError
                        ? redAccent.withOpacity(0.1)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOTPBox(index)),
              ),
            ),
          ),
          
          // Error Message
          if (_hasError && _errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 28),
          
          // Verify Button
          GestureDetector(
            onTap: _isLoading ? null : _handleVerify,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isOtpComplete
                      ? [darkCard, darkCard.withOpacity(0.9)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: (_isOtpComplete ? darkCard : Colors.grey).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(mintGreen),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Verify Code",
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
          
          const SizedBox(height: 24),
          
          // Resend Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive the code? ",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: _canResend ? _handleResend : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _canResend ? blueAccent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _canResend ? "Resend Code" : "Wait $_formattedTime",
                    style: TextStyle(
                      color: _canResend ? blueAccent : Colors.black.withOpacity(0.3),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Change Email Link
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              "Change email address",
              style: TextStyle(
                color: Colors.black.withOpacity(0.4),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPBox(int index) {
    final hasValue = _controllers[index].text.isNotEmpty;
    final isFocused = _focusNodes[index].hasFocus;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: hasValue
            ? _hasError
                ? redAccent.withOpacity(0.1)
                : blueAccent.withOpacity(0.1)
            : bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasError
              ? redAccent
              : isFocused
                  ? blueAccent
                  : hasValue
                      ? blueAccent.withOpacity(0.5)
                      : Colors.black.withOpacity(0.1),
          width: isFocused || hasValue ? 2 : 1.5,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: (_hasError ? redAccent : blueAccent).withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onKeyPressed(index, event),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6, // Allow paste
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _hasError ? redAccent : darkCard,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) => _onOtpChanged(index, value),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
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
              color: greenAccent.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            // Success Animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: greenAccent.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 45,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Email Verified!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Redirecting you to the app...",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
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