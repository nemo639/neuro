import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/features/auth/register.dart';
import 'package:neuroverse/features/auth/forgot_password_screen.dart';
import 'package:neuroverse/core/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  bool showPassword = false;
  bool isLoading = false;
  bool rememberMe = false;
  
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  
  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  
  String? emailError;
  String? passwordError;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color greenAccent = Color(0xFF10B981);

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

 // ============================================================
// PROFESSIONAL EMAIL VALIDATOR
// Follows RFC 5322, RFC 5321, and WHATWG HTML Living Standard
// Similar to Google, Microsoft, and other major companies
// ============================================================

// ============================================================
// PROFESSIONAL EMAIL VALIDATOR
// Follows RFC 5322, RFC 5321, and WHATWG HTML Living Standard
// Similar to Google, Microsoft, and other major companies
// ============================================================

/// Main email validation function
/// Returns true if valid, false if invalid
/// Sets emailError state with specific error message
// ============================================================
// PROFESSIONAL EMAIL VALIDATOR
// Follows RFC 5322, RFC 5321, and WHATWG HTML Living Standard
// Similar to Google, Microsoft, and other major companies
// ============================================================

/// Main email validation function
/// Returns true if valid, false if invalid
/// Sets emailError state with specific error message
/// 


bool _validateEmail(String email) {
  // Trim whitespace
  email = email.trim().toLowerCase();
  
  // ============ BASIC CHECKS ============
  
  // Check if empty
  if (email.isEmpty) {
    setState(() => emailError = "Email is required");
    return false;
  }
  
  // RFC 5321: Maximum email length is 254 characters
  if (email.length > 254) {
    setState(() => emailError = "Email is too long");
    return false;
  }
  
  // Minimum practical length (a@b.co = 6 chars)
  if (email.length < 6) {
    setState(() => emailError = "Email is too short");
    return false;
  }
  
  // ============ @ SYMBOL CHECK ============
  
  // Must contain exactly one @ symbol
  final atCount = '@'.allMatches(email).length;
  if (atCount == 0) {
    setState(() => emailError = "Email must contain @");
    return false;
  }
  if (atCount > 1) {
    setState(() => emailError = "Email can only contain one @");
    return false;
  }
  
  final atIndex = email.indexOf('@');
  final localPart = email.substring(0, atIndex);
  final domainPart = email.substring(atIndex + 1);
  
  // ============ LOCAL PART VALIDATION (before @) ============
  
  // RFC 5321: Local part max length is 64 characters
  if (localPart.isEmpty) {
    setState(() => emailError = "Email username is required");
    return false;
  }
  
  if (localPart.length > 64) {
    setState(() => emailError = "Email username is too long");
    return false;
  }
  
  // Cannot start or end with a dot
  if (localPart.startsWith('.')) {
    setState(() => emailError = "Email cannot start with a dot");
    return false;
  }
  
  if (localPart.endsWith('.')) {
    setState(() => emailError = "Email cannot end with a dot before @");
    return false;
  }
  
  // Check for consecutive dots (..)
  if (localPart.contains('..')) {
    setState(() => emailError = "Email cannot have consecutive dots");
    return false;
  }
  
  // Valid characters in local part: a-z, 0-9, and . _ % + -
  // This is the practical subset used by major providers
  final localPartRegex = RegExp(r'^[a-zA-Z0-9._%+-]+$');
  if (!localPartRegex.hasMatch(localPart)) {
    setState(() => emailError = "Email contains invalid characters");
    return false;
  }
  
  // Google/Microsoft Rule: Usernames of 8+ characters must have at least one letter
  // Prevents spam accounts with purely numeric usernames
  if (localPart.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length >= 8) {
    if (!RegExp(r'[a-zA-Z]').hasMatch(localPart)) {
      setState(() => emailError = "Email username must contain at least one letter");
      return false;
    }
  }
  
  // ============ DOMAIN PART VALIDATION (after @) ============
  
  if (domainPart.isEmpty) {
    setState(() => emailError = "Domain is required");
    return false;
  }
  
  // RFC 5321: Domain max length is 253 characters
  if (domainPart.length > 253) {
    setState(() => emailError = "Domain is too long");
    return false;
  }
  
  // Domain must contain at least one dot
  if (!domainPart.contains('.')) {
    setState(() => emailError = "Please enter a complete domain (e.g., gmail.com)");
    return false;
  }
  
  // Check for invalid characters in domain
  // Valid: a-z, 0-9, dots, and hyphens
  final domainRegex = RegExp(r'^[a-zA-Z0-9.-]+$');
  if (!domainRegex.hasMatch(domainPart)) {
    setState(() => emailError = "Domain contains invalid characters");
    return false;
  }
  
  // Cannot start or end with dot or hyphen
  if (domainPart.startsWith('.') || domainPart.startsWith('-')) {
    setState(() => emailError = "Domain cannot start with a dot or hyphen");
    return false;
  }
  
  if (domainPart.endsWith('.') || domainPart.endsWith('-')) {
    setState(() => emailError = "Domain cannot end with a dot or hyphen");
    return false;
  }
  
  // Check for consecutive dots in domain
  if (domainPart.contains('..')) {
    setState(() => emailError = "Domain cannot have consecutive dots");
    return false;
  }
  
  // ============ DOMAIN LABELS VALIDATION ============
  
  final domainLabels = domainPart.split('.');
  
  // Must have at least 2 labels (e.g., gmail.com)
  if (domainLabels.length < 2) {
    setState(() => emailError = "Please enter a valid domain");
    return false;
  }
  
  // Validate each domain label
  for (int i = 0; i < domainLabels.length; i++) {
    final label = domainLabels[i];
    
    // Each label must be 1-63 characters
    if (label.isEmpty) {
      setState(() => emailError = "Invalid domain format");
      return false;
    }
    
    if (label.length > 63) {
      setState(() => emailError = "Domain part is too long");
      return false;
    }
    
    // Labels cannot start or end with hyphen
    if (label.startsWith('-') || label.endsWith('-')) {
      setState(() => emailError = "Domain parts cannot start or end with hyphen");
      return false;
    }
  }
  
  // ============ TLD (TOP-LEVEL DOMAIN) VALIDATION ============
  
  final tld = domainLabels.last.toLowerCase();
  
  // TLD must be at least 2 characters
  if (tld.length < 2) {
    setState(() => emailError = "Invalid domain extension");
    return false;
  }
  
  // TLD should only contain letters (no numbers except for IDN)
  final tldRegex = RegExp(r'^[a-zA-Z]{2,}$');
  if (!tldRegex.hasMatch(tld)) {
    // Allow special cases like xn-- (punycode)
    if (!tld.startsWith('xn--')) {
      setState(() => emailError = "Invalid domain extension");
      return false;
    }
  }
  
  // ============ DUPLICATE TLD DETECTION ============
  // Catches: gmail.com.com, yahoo.com.org, etc.
  
  final commonTLDs = {
    'com', 'net', 'org', 'edu', 'gov', 'mil', 'int', 'io', 'ai', 'app',
    'dev', 'co', 'me', 'info', 'biz', 'xyz', 'online', 'site', 'tech',
    'store', 'shop', 'blog', 'cloud', 'email', 'live', 'pro', 'tv', 'cc',
  };
  
  final countryTLDs = {
    'uk', 'us', 'ca', 'au', 'de', 'fr', 'jp', 'cn', 'in', 'pk', 'br',
    'it', 'es', 'nl', 'ru', 'kr', 'mx', 'nz', 'za', 'sg', 'hk', 'ae',
  };
  
  // Valid second-level country domains (like co.uk, com.au)
  final validSecondLevelDomains = {
    'uk': ['co', 'ac', 'gov', 'org', 'net', 'me'],
    'au': ['com', 'net', 'org', 'edu', 'gov'],
    'nz': ['co', 'net', 'org', 'ac', 'govt'],
    'jp': ['co', 'ac', 'go', 'or', 'ne'],
    'in': ['co', 'net', 'org', 'edu', 'gov', 'ac'],
    'za': ['co', 'net', 'org', 'edu', 'gov', 'ac'],
    'br': ['com', 'net', 'org', 'edu', 'gov'],
    'cn': ['com', 'net', 'org', 'edu', 'gov'],
    'pk': ['com', 'net', 'org', 'edu', 'gov'],
  };
  
  // Check for suspicious duplicate TLD patterns
  if (domainLabels.length >= 3) {
    final secondToLast = domainLabels[domainLabels.length - 2].toLowerCase();
    
    // If both second-to-last and last are common TLDs
    if (commonTLDs.contains(secondToLast) && commonTLDs.contains(tld)) {
      // This is likely a typo like gmail.com.com
      setState(() => emailError = "Invalid domain - possible duplicate extension");
      return false;
    }
    
    // Allow valid patterns like example.co.uk
    if (commonTLDs.contains(secondToLast) && countryTLDs.contains(tld)) {
      // Check if this is a valid country second-level domain
      if (!validSecondLevelDomains.containsKey(tld) ||
          !validSecondLevelDomains[tld]!.contains(secondToLast)) {
        // Could be typo like gmail.com.pk instead of gmail.pk
        // We'll allow it but could warn - for now, allow
      }
    }
  }
  
  // ============ COMMON TYPO DETECTION ============
  
  // Common domain typos
  final commonDomains = {
    'gmail.com': ['gmal.com', 'gmial.com', 'gmaill.com', 'gmail.co', 'gmail.cm', 'gamil.com', 'gnail.com'],
    'yahoo.com': ['yaho.com', 'yahooo.com', 'yahoo.co', 'yahoo.cm', 'yhaoo.com'],
    'hotmail.com': ['hotmal.com', 'hotmai.com', 'hotmail.co', 'hotmail.cm'],
    'outlook.com': ['outlok.com', 'outllook.com', 'outlook.co'],
    'icloud.com': ['iclould.com', 'icloud.co'],
  };
  
  for (final entry in commonDomains.entries) {
    if (entry.value.contains(domainPart)) {
      setState(() => emailError = "Did you mean ${entry.key}?");
      return false;
    }
  }
  
  // ============ ALL CHECKS PASSED ============
  
  setState(() => emailError = null);
  return true;
}

// ============================================================
// SIMPLE VERSION (If you prefer a shorter validator)
// ============================================================

/// Simplified email validation using WHATWG standard
/// This is what browsers use for <input type="email">
bool _validateEmailSimple(String email) {
  email = email.trim();
  
  if (email.isEmpty) {
    setState(() => emailError = "Email is required");
    return false;
  }
  
  // WHATWG HTML Living Standard regex
  final emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );
  
  if (!emailRegex.hasMatch(email)) {
    setState(() => emailError = "Please enter a valid email address");
    return false;
  }
  
  // Length check
  if (email.length > 254) {
    setState(() => emailError = "Email is too long");
    return false;
  }
  
  // Google/Microsoft Rule: Usernames of 8+ chars must have at least one letter
  final localPart = email.split('@').first;
  if (localPart.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').length >= 8) {
    if (!RegExp(r'[a-zA-Z]').hasMatch(localPart)) {
      setState(() => emailError = "Email username must contain at least one letter");
      return false;
    }
  }
  
  // Check for duplicate TLDs (gmail.com.com)
  final domain = email.split('@').last.toLowerCase();
  final parts = domain.split('.');
  if (parts.length >= 3) {
    final last = parts.last;
    final secondLast = parts[parts.length - 2];
    final commonTLDs = ['com', 'net', 'org', 'io', 'co', 'edu'];
    if (commonTLDs.contains(last) && commonTLDs.contains(secondLast)) {
      setState(() => emailError = "Invalid domain format");
      return false;
    }
  }
  
  setState(() => emailError = null);
  return true;
}
  /// Main password validation function
  bool _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => passwordError = "Password is required");
      return false;
    }
    
    if (password.length < 8) {
      setState(() => passwordError = "Password must be at least 8 characters");
      return false;
    }
    
    setState(() => passwordError = null);
    return true;
  }

  Future<void> _handleSignIn() async {
  HapticFeedback.mediumImpact();
  
  bool isEmailValid = _validateEmail(emailController.text.trim());
  bool isPasswordValid = _validatePassword(passwordController.text);
  
  if (isEmailValid && isPasswordValid) {
    setState(() => isLoading = true);
    
    // Call API
    final result = await ApiService.login(
      email: emailController.text.trim(),
      password: passwordController.text,
    );
    
    setState(() => isLoading = false);
    
    if (mounted) {
      if (result['success']) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Login failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Animated Background Elements
          _buildAnimatedBackground(),
          
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 50),
                    _buildLogo(),
                    const SizedBox(height: 40),
                    _buildWelcomeHeader(),
                    const SizedBox(height: 40),
                    _buildLoginForm(),
                    const SizedBox(height: 30),
                    _buildSocialSection(),
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
        // Top right blob
        Positioned(
          top: -120,
          right: -80,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_floatingController.value * math.pi) * 20,
                  _floatingController.value * 40,
                ),
                child: Transform.rotate(
                  angle: _floatingController.value * 0.3,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          softLavender,
                          softLavender.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Bottom left blob
        Positioned(
          bottom: -100,
          left: -80,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -math.cos(_floatingController.value * math.pi) * 25,
                  -_floatingController.value * 50,
                ),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        mintGreen,
                        mintGreen.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Center accent blob
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          right: -50,
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_floatingController.value * math.pi * 2) * 15,
                  math.cos(_floatingController.value * math.pi) * 20,
                ),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        creamBeige.withOpacity(0.8),
                        creamBeige.withOpacity(0.1),
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

  Widget _buildLogo() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: darkCard.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated pulse ring
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60 + (_pulseController.value * 10),
                    height: 60 + (_pulseController.value * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: mintGreen.withOpacity(0.3 - _pulseController.value * 0.2),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              // Brain icon
              CustomPaint(
                size: const Size(40, 40),
                painter: BrainLogoPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 32,
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: const Text(
                      "",
                      style: TextStyle(fontSize: 32),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Sign in to continue your brain health journey",
            style: TextStyle(
              fontSize: 15,
              color: Colors.black.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

    

  Widget _buildLoginForm() {
    return _buildAnimatedWidget(
      delay: 0.2,
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
            _buildInputField(
              label: "Email Address",
              hint: "your.email@example.com",
              icon: Icons.email_outlined,
              controller: emailController,
              focusNode: emailFocus,
              errorText: emailError,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                if (emailError != null) _validateEmail(value);
              },
              onSubmitted: (_) {
                FocusScope.of(context).requestFocus(passwordFocus);
              },
            ),
            
            const SizedBox(height: 20),
            
            // Password Field
            _buildInputField(
              label: "Password",
              hint: "Enter your password",
              icon: Icons.lock_outline_rounded,
              controller: passwordController,
              focusNode: passwordFocus,
              isPassword: true,
              errorText: passwordError,
              onChanged: (value) {
                if (passwordError != null) _validatePassword(value);
              },
              onSubmitted: (_) => _handleSignIn(),
            ),
            
            const SizedBox(height: 16),
            
            // Remember Me & Forgot Password Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Remember Me
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => rememberMe = !rememberMe);
                  },
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: rememberMe ? darkCard : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: rememberMe ? darkCard : Colors.black.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: rememberMe
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Remember me",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Forgot Password
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // Sign In Button
            _buildSignInButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    bool isPassword = false,
    String? errorText,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
              color: errorText != null
                  ? Colors.red.withOpacity(0.5)
                  : focusNode.hasFocus
                      ? blueAccent.withOpacity(0.5)
                      : Colors.black.withOpacity(0.06),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && !showPassword,
            keyboardType: keyboardType,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.25),
                fontSize: 15,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  icon,
                  color: errorText != null
                      ? Colors.red.withOpacity(0.7)
                      : Colors.black.withOpacity(0.4),
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: isPassword
                  ? GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => showPassword = !showPassword);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 14),
                        child: Icon(
                          showPassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: Colors.black.withOpacity(0.4),
                          size: 22,
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: Colors.red.shade400),
              const SizedBox(width: 6),
              Text(
                errorText,
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSignInButton() {
    return GestureDetector(
      onTap: isLoading ? null : _handleSignIn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              darkCard,
              darkCard.withOpacity(0.9),
            ],
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
                    const Text(
                      "Sign In",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSocialSection() {
  return _buildAnimatedWidget(
    delay: 0.3,
    child: Column(
      children: [
        // Divider with text
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Or continue with",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Social Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(
              child: _buildGoogleLogo(),
              onTap: () => _handleSocialLogin('Google'),
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              child: _buildAppleLogo(),
              backgroundColor: Colors.black,
              onTap: () => _handleSocialLogin('Apple'),
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              child: _buildFacebookLogo(),
              backgroundColor: const Color(0xFF1877F2),
              onTap: () => _handleSocialLogin('Facebook'),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        // Sign Up Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: darkCard,
                      width: 2,
                    ),
                  ),
                ),
                child: const Text(
                  "Sign Up",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        
        // ==================== DOCTOR & ADMIN SIGN-IN ====================
        const SizedBox(height: 28),
        
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: Colors.black.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Healthcare Professional?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        Row(
          children: [
            Expanded(
              child: _buildProfessionalButton(
                icon: Icons.medical_services_rounded,
                label: 'Sign in as Doctor',
                color: const Color(0xFF0D9488),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/doctor-login');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildProfessionalButton(
                icon: Icons.admin_panel_settings_rounded,
                label: 'Continue as Admin',
                color: const Color(0xFF7C3AED),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/admin-login');
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Helper method for professional buttons
Widget _buildProfessionalButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSocialButton({
    required Widget child,
    Color backgroundColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: backgroundColor == Colors.white
              ? Border.all(color: Colors.black.withOpacity(0.08), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: backgroundColor == Colors.white
                  ? Colors.black.withOpacity(0.06)
                  : backgroundColor.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return CustomPaint(
      size: const Size(24, 24),
      painter: GoogleLogoPainter(),
    );
  }

  Widget _buildAppleLogo() {
    return const Icon(
      Icons.apple_rounded,
      color: Colors.white,
      size: 28,
    );
  }

  Widget _buildFacebookLogo() {
    return const Text(
      'f',
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        fontFamily: 'Arial',
      ),
    );
  }

  void _handleSocialLogin(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Continue with $provider',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: darkCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

// Custom Painters for Logos
class BrainLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8E8D1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Left hemisphere
    final leftPath = Path();
    leftPath.moveTo(center.dx - 2, center.dy - 12);
    leftPath.quadraticBezierTo(center.dx - 14, center.dy - 10, center.dx - 12, center.dy);
    leftPath.quadraticBezierTo(center.dx - 16, center.dy + 5, center.dx - 10, center.dy + 12);
    leftPath.quadraticBezierTo(center.dx - 4, center.dy + 16, center.dx - 2, center.dy + 12);
    
    // Right hemisphere
    final rightPath = Path();
    rightPath.moveTo(center.dx + 2, center.dy - 12);
    rightPath.quadraticBezierTo(center.dx + 14, center.dy - 10, center.dx + 12, center.dy);
    rightPath.quadraticBezierTo(center.dx + 16, center.dy + 5, center.dx + 10, center.dy + 12);
    rightPath.quadraticBezierTo(center.dx + 4, center.dy + 16, center.dx + 2, center.dy + 12);
    
    canvas.drawPath(leftPath, paint);
    canvas.drawPath(rightPath, paint);
    
    // Center line
    canvas.drawLine(
      Offset(center.dx, center.dy - 12),
      Offset(center.dx, center.dy + 12),
      paint..strokeWidth = 1.5,
    );
    
    // Neural connections
    paint.strokeWidth = 1.5;
    canvas.drawLine(Offset(center.dx - 8, center.dy - 4), Offset(center.dx - 4, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 8, center.dy - 4), Offset(center.dx + 4, center.dy), paint);
    canvas.drawLine(Offset(center.dx - 6, center.dy + 6), Offset(center.dx - 2, center.dy + 4), paint);
    canvas.drawLine(Offset(center.dx + 6, center.dy + 6), Offset(center.dx + 2, center.dy + 4), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Blue arc (top right)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi / 4,
      -math.pi / 2,
      false,
      bluePaint,
    );
    
    // Green arc (bottom right)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      math.pi / 4,
      math.pi / 2,
      false,
      greenPaint,
    );
    
    // Yellow arc (bottom left)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      math.pi * 3 / 4,
      math.pi / 2,
      false,
      yellowPaint,
    );
    
    // Red arc (top left)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi * 3 / 4,
      -math.pi / 2,
      false,
      redPaint,
    );
    
    // Blue horizontal line
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius - 2, center.dy),
      bluePaint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  
}

