import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/loading_bars.dart';
import 'package:neuroverse/core/responsive.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool agreeToTerms = false;
  bool isLoading = false;
  int currentStep = 0; // 0 = basic info, 1 = account details
  
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  final FocusNode firstNameFocus = FocusNode();
  final FocusNode lastNameFocus = FocusNode();
  final FocusNode emailFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  final FocusNode confirmPasswordFocus = FocusNode();
  
  late AnimationController _floatingController;
  late AnimationController _pageController;
  late AnimationController _pulseController;
  
  String? firstNameError;
  String? lastNameError;
  String? emailError;
  String? phoneError;
  String? passwordError;
  String? confirmPasswordError;
  
  DateTime? selectedDate;
  String? selectedGender;

  // Country code for phone
  String _selectedCountryCode = '+92';
  String _selectedCountryFlag = '🇵🇰';

  final List<Map<String, String>> _countryCodes = [
    {'flag': '🇵🇰', 'code': '+92', 'name': 'Pakistan'},
    {'flag': '🇦🇫', 'code': '+93', 'name': 'Afghanistan'},
    {'flag': '🇦🇱', 'code': '+355', 'name': 'Albania'},
    {'flag': '🇩🇿', 'code': '+213', 'name': 'Algeria'},
    {'flag': '🇦🇩', 'code': '+376', 'name': 'Andorra'},
    {'flag': '🇦🇴', 'code': '+244', 'name': 'Angola'},
    {'flag': '🇦🇬', 'code': '+1268', 'name': 'Antigua & Barbuda'},
    {'flag': '🇦🇷', 'code': '+54', 'name': 'Argentina'},
    {'flag': '🇦🇲', 'code': '+374', 'name': 'Armenia'},
    {'flag': '🇦🇺', 'code': '+61', 'name': 'Australia'},
    {'flag': '🇦🇹', 'code': '+43', 'name': 'Austria'},
    {'flag': '🇦🇿', 'code': '+994', 'name': 'Azerbaijan'},
    {'flag': '🇧🇸', 'code': '+1242', 'name': 'Bahamas'},
    {'flag': '🇧🇭', 'code': '+973', 'name': 'Bahrain'},
    {'flag': '🇧🇩', 'code': '+880', 'name': 'Bangladesh'},
    {'flag': '🇧🇧', 'code': '+1246', 'name': 'Barbados'},
    {'flag': '🇧🇾', 'code': '+375', 'name': 'Belarus'},
    {'flag': '🇧🇪', 'code': '+32', 'name': 'Belgium'},
    {'flag': '🇧🇿', 'code': '+501', 'name': 'Belize'},
    {'flag': '🇧🇯', 'code': '+229', 'name': 'Benin'},
    {'flag': '🇧🇹', 'code': '+975', 'name': 'Bhutan'},
    {'flag': '🇧🇴', 'code': '+591', 'name': 'Bolivia'},
    {'flag': '🇧🇦', 'code': '+387', 'name': 'Bosnia & Herzegovina'},
    {'flag': '🇧🇼', 'code': '+267', 'name': 'Botswana'},
    {'flag': '🇧🇷', 'code': '+55', 'name': 'Brazil'},
    {'flag': '🇧🇳', 'code': '+673', 'name': 'Brunei'},
    {'flag': '🇧🇬', 'code': '+359', 'name': 'Bulgaria'},
    {'flag': '🇧🇫', 'code': '+226', 'name': 'Burkina Faso'},
    {'flag': '🇧🇮', 'code': '+257', 'name': 'Burundi'},
    {'flag': '🇰🇭', 'code': '+855', 'name': 'Cambodia'},
    {'flag': '🇨🇲', 'code': '+237', 'name': 'Cameroon'},
    {'flag': '🇨🇦', 'code': '+1', 'name': 'Canada'},
    {'flag': '🇨🇻', 'code': '+238', 'name': 'Cape Verde'},
    {'flag': '🇨🇫', 'code': '+236', 'name': 'Central African Republic'},
    {'flag': '🇹🇩', 'code': '+235', 'name': 'Chad'},
    {'flag': '🇨🇱', 'code': '+56', 'name': 'Chile'},
    {'flag': '🇨🇳', 'code': '+86', 'name': 'China'},
    {'flag': '🇨🇴', 'code': '+57', 'name': 'Colombia'},
    {'flag': '🇰🇲', 'code': '+269', 'name': 'Comoros'},
    {'flag': '🇨🇬', 'code': '+242', 'name': 'Congo'},
    {'flag': '🇨🇷', 'code': '+506', 'name': 'Costa Rica'},
    {'flag': '🇭🇷', 'code': '+385', 'name': 'Croatia'},
    {'flag': '🇨🇺', 'code': '+53', 'name': 'Cuba'},
    {'flag': '🇨🇾', 'code': '+357', 'name': 'Cyprus'},
    {'flag': '🇨🇿', 'code': '+420', 'name': 'Czech Republic'},
    {'flag': '🇩🇰', 'code': '+45', 'name': 'Denmark'},
    {'flag': '🇩🇯', 'code': '+253', 'name': 'Djibouti'},
    {'flag': '🇩🇴', 'code': '+1809', 'name': 'Dominican Republic'},
    {'flag': '🇪🇨', 'code': '+593', 'name': 'Ecuador'},
    {'flag': '🇪🇬', 'code': '+20', 'name': 'Egypt'},
    {'flag': '🇸🇻', 'code': '+503', 'name': 'El Salvador'},
    {'flag': '🇬🇶', 'code': '+240', 'name': 'Equatorial Guinea'},
    {'flag': '🇪🇷', 'code': '+291', 'name': 'Eritrea'},
    {'flag': '🇪🇪', 'code': '+372', 'name': 'Estonia'},
    {'flag': '🇪🇹', 'code': '+251', 'name': 'Ethiopia'},
    {'flag': '🇫🇯', 'code': '+679', 'name': 'Fiji'},
    {'flag': '🇫🇮', 'code': '+358', 'name': 'Finland'},
    {'flag': '🇫🇷', 'code': '+33', 'name': 'France'},
    {'flag': '🇬🇦', 'code': '+241', 'name': 'Gabon'},
    {'flag': '🇬🇲', 'code': '+220', 'name': 'Gambia'},
    {'flag': '🇬🇪', 'code': '+995', 'name': 'Georgia'},
    {'flag': '🇩🇪', 'code': '+49', 'name': 'Germany'},
    {'flag': '🇬🇭', 'code': '+233', 'name': 'Ghana'},
    {'flag': '🇬🇷', 'code': '+30', 'name': 'Greece'},
    {'flag': '🇬🇩', 'code': '+1473', 'name': 'Grenada'},
    {'flag': '🇬🇹', 'code': '+502', 'name': 'Guatemala'},
    {'flag': '🇬🇳', 'code': '+224', 'name': 'Guinea'},
    {'flag': '🇬🇾', 'code': '+592', 'name': 'Guyana'},
    {'flag': '🇭🇹', 'code': '+509', 'name': 'Haiti'},
    {'flag': '🇭🇳', 'code': '+504', 'name': 'Honduras'},
    {'flag': '🇭🇰', 'code': '+852', 'name': 'Hong Kong'},
    {'flag': '🇭🇺', 'code': '+36', 'name': 'Hungary'},
    {'flag': '🇮🇸', 'code': '+354', 'name': 'Iceland'},
    {'flag': '🇮🇳', 'code': '+91', 'name': 'India'},
    {'flag': '🇮🇩', 'code': '+62', 'name': 'Indonesia'},
    {'flag': '🇮🇷', 'code': '+98', 'name': 'Iran'},
    {'flag': '🇮🇶', 'code': '+964', 'name': 'Iraq'},
    {'flag': '🇮🇪', 'code': '+353', 'name': 'Ireland'},
    {'flag': '🇮🇱', 'code': '+972', 'name': 'Israel'},
    {'flag': '🇮🇹', 'code': '+39', 'name': 'Italy'},
    {'flag': '🇯🇲', 'code': '+1876', 'name': 'Jamaica'},
    {'flag': '🇯🇵', 'code': '+81', 'name': 'Japan'},
    {'flag': '🇯🇴', 'code': '+962', 'name': 'Jordan'},
    {'flag': '🇰🇿', 'code': '+7', 'name': 'Kazakhstan'},
    {'flag': '🇰🇪', 'code': '+254', 'name': 'Kenya'},
    {'flag': '🇰🇼', 'code': '+965', 'name': 'Kuwait'},
    {'flag': '🇰🇬', 'code': '+996', 'name': 'Kyrgyzstan'},
    {'flag': '🇱🇦', 'code': '+856', 'name': 'Laos'},
    {'flag': '🇱🇻', 'code': '+371', 'name': 'Latvia'},
    {'flag': '🇱🇧', 'code': '+961', 'name': 'Lebanon'},
    {'flag': '🇱🇸', 'code': '+266', 'name': 'Lesotho'},
    {'flag': '🇱🇷', 'code': '+231', 'name': 'Liberia'},
    {'flag': '🇱🇾', 'code': '+218', 'name': 'Libya'},
    {'flag': '🇱🇮', 'code': '+423', 'name': 'Liechtenstein'},
    {'flag': '🇱🇹', 'code': '+370', 'name': 'Lithuania'},
    {'flag': '🇱🇺', 'code': '+352', 'name': 'Luxembourg'},
    {'flag': '🇲🇴', 'code': '+853', 'name': 'Macau'},
    {'flag': '🇲🇬', 'code': '+261', 'name': 'Madagascar'},
    {'flag': '🇲🇼', 'code': '+265', 'name': 'Malawi'},
    {'flag': '🇲🇾', 'code': '+60', 'name': 'Malaysia'},
    {'flag': '🇲🇻', 'code': '+960', 'name': 'Maldives'},
    {'flag': '🇲🇱', 'code': '+223', 'name': 'Mali'},
    {'flag': '🇲🇹', 'code': '+356', 'name': 'Malta'},
    {'flag': '🇲🇷', 'code': '+222', 'name': 'Mauritania'},
    {'flag': '🇲🇺', 'code': '+230', 'name': 'Mauritius'},
    {'flag': '🇲🇽', 'code': '+52', 'name': 'Mexico'},
    {'flag': '🇲🇩', 'code': '+373', 'name': 'Moldova'},
    {'flag': '🇲🇨', 'code': '+377', 'name': 'Monaco'},
    {'flag': '🇲🇳', 'code': '+976', 'name': 'Mongolia'},
    {'flag': '🇲🇪', 'code': '+382', 'name': 'Montenegro'},
    {'flag': '🇲🇦', 'code': '+212', 'name': 'Morocco'},
    {'flag': '🇲🇿', 'code': '+258', 'name': 'Mozambique'},
    {'flag': '🇲🇲', 'code': '+95', 'name': 'Myanmar'},
    {'flag': '🇳🇦', 'code': '+264', 'name': 'Namibia'},
    {'flag': '🇳🇵', 'code': '+977', 'name': 'Nepal'},
    {'flag': '🇳🇱', 'code': '+31', 'name': 'Netherlands'},
    {'flag': '🇳🇿', 'code': '+64', 'name': 'New Zealand'},
    {'flag': '🇳🇮', 'code': '+505', 'name': 'Nicaragua'},
    {'flag': '🇳🇪', 'code': '+227', 'name': 'Niger'},
    {'flag': '🇳🇬', 'code': '+234', 'name': 'Nigeria'},
    {'flag': '🇰🇵', 'code': '+850', 'name': 'North Korea'},
    {'flag': '🇲🇰', 'code': '+389', 'name': 'North Macedonia'},
    {'flag': '🇳🇴', 'code': '+47', 'name': 'Norway'},
    {'flag': '🇴🇲', 'code': '+968', 'name': 'Oman'},
    {'flag': '🇵🇦', 'code': '+507', 'name': 'Panama'},
    {'flag': '🇵🇬', 'code': '+675', 'name': 'Papua New Guinea'},
    {'flag': '🇵🇾', 'code': '+595', 'name': 'Paraguay'},
    {'flag': '🇵🇪', 'code': '+51', 'name': 'Peru'},
    {'flag': '🇵🇭', 'code': '+63', 'name': 'Philippines'},
    {'flag': '🇵🇱', 'code': '+48', 'name': 'Poland'},
    {'flag': '🇵🇹', 'code': '+351', 'name': 'Portugal'},
    {'flag': '🇶🇦', 'code': '+974', 'name': 'Qatar'},
    {'flag': '🇷🇴', 'code': '+40', 'name': 'Romania'},
    {'flag': '🇷🇺', 'code': '+7', 'name': 'Russia'},
    {'flag': '🇷🇼', 'code': '+250', 'name': 'Rwanda'},
    {'flag': '🇸🇦', 'code': '+966', 'name': 'Saudi Arabia'},
    {'flag': '🇸🇳', 'code': '+221', 'name': 'Senegal'},
    {'flag': '🇷🇸', 'code': '+381', 'name': 'Serbia'},
    {'flag': '🇸🇬', 'code': '+65', 'name': 'Singapore'},
    {'flag': '🇸🇰', 'code': '+421', 'name': 'Slovakia'},
    {'flag': '🇸🇮', 'code': '+386', 'name': 'Slovenia'},
    {'flag': '🇸🇴', 'code': '+252', 'name': 'Somalia'},
    {'flag': '🇿🇦', 'code': '+27', 'name': 'South Africa'},
    {'flag': '🇰🇷', 'code': '+82', 'name': 'South Korea'},
    {'flag': '🇸🇸', 'code': '+211', 'name': 'South Sudan'},
    {'flag': '🇪🇸', 'code': '+34', 'name': 'Spain'},
    {'flag': '🇱🇰', 'code': '+94', 'name': 'Sri Lanka'},
    {'flag': '🇸🇩', 'code': '+249', 'name': 'Sudan'},
    {'flag': '🇸🇷', 'code': '+597', 'name': 'Suriname'},
    {'flag': '🇸🇪', 'code': '+46', 'name': 'Sweden'},
    {'flag': '🇨🇭', 'code': '+41', 'name': 'Switzerland'},
    {'flag': '🇸🇾', 'code': '+963', 'name': 'Syria'},
    {'flag': '🇹🇼', 'code': '+886', 'name': 'Taiwan'},
    {'flag': '🇹🇯', 'code': '+992', 'name': 'Tajikistan'},
    {'flag': '🇹🇿', 'code': '+255', 'name': 'Tanzania'},
    {'flag': '🇹🇭', 'code': '+66', 'name': 'Thailand'},
    {'flag': '🇹🇬', 'code': '+228', 'name': 'Togo'},
    {'flag': '🇹🇹', 'code': '+1868', 'name': 'Trinidad & Tobago'},
    {'flag': '🇹🇳', 'code': '+216', 'name': 'Tunisia'},
    {'flag': '🇹🇷', 'code': '+90', 'name': 'Turkey'},
    {'flag': '🇹🇲', 'code': '+993', 'name': 'Turkmenistan'},
    {'flag': '🇺🇬', 'code': '+256', 'name': 'Uganda'},
    {'flag': '🇺🇦', 'code': '+380', 'name': 'Ukraine'},
    {'flag': '🇦🇪', 'code': '+971', 'name': 'UAE'},
    {'flag': '🇬🇧', 'code': '+44', 'name': 'United Kingdom'},
    {'flag': '🇺🇸', 'code': '+1', 'name': 'United States'},
    {'flag': '🇺🇾', 'code': '+598', 'name': 'Uruguay'},
    {'flag': '🇺🇿', 'code': '+998', 'name': 'Uzbekistan'},
    {'flag': '🇻🇪', 'code': '+58', 'name': 'Venezuela'},
    {'flag': '🇻🇳', 'code': '+84', 'name': 'Vietnam'},
    {'flag': '🇾🇪', 'code': '+967', 'name': 'Yemen'},
    {'flag': '🇿🇲', 'code': '+260', 'name': 'Zambia'},
    {'flag': '🇿🇼', 'code': '+263', 'name': 'Zimbabwe'},
  ];
  
  int passwordStrength = 0;
  String passwordStrengthText = '';
  Color passwordStrengthColor = Colors.grey;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color orangeAccent = Color(0xFFF97316);
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
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstNameFocus.dispose();
    lastNameFocus.dispose();
    emailFocus.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
    super.dispose();
  }

  // Validations
  bool _validateFirstName(String name) {
    if (name.isEmpty) {
      setState(() => firstNameError = "First name is required");
      return false;
    }
    if (name.length < 2) {
      setState(() => firstNameError = "Name must be at least 2 characters");
      return false;
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      setState(() => firstNameError = "Name can only contain letters");
      return false;
    }
    setState(() => firstNameError = null);
    return true;
  }

  bool _validateLastName(String name) {
    if (name.isEmpty) {
      setState(() => lastNameError = "Last name is required");
      return false;
    }
    if (name.length < 2) {
      setState(() => lastNameError = "Name must be at least 2 characters");
      return false;
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(name)) {
      setState(() => lastNameError = "Name can only contain letters");
      return false;
    }
    setState(() => lastNameError = null);
    return true;
  }

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

  bool _validatePhone(String phone) {
    if (phone.isEmpty) {
      setState(() => phoneError = "Phone number is required");
      return false;
    }
    
    // Remove spaces, dashes, and parentheses for validation
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Check if it starts with + for international format
    if (cleanPhone.startsWith('+')) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    if (cleanPhone.length < 10 || cleanPhone.length > 15) {
      setState(() => phoneError = "Enter a valid phone number (10-15 digits)");
      return false;
    }
    
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanPhone)) {
      setState(() => phoneError = "Phone number can only contain digits");
      return false;
    }
    
    setState(() => phoneError = null);
    return true;
  }

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        passwordStrength = 0;
        passwordStrengthText = '';
      });
      return;
    }

    int strength = 0;
    
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    setState(() {
      passwordStrength = strength;
      if (strength <= 2) {
        passwordStrengthText = "Weak";
        passwordStrengthColor = redAccent;
      } else if (strength <= 4) {
        passwordStrengthText = "Medium";
        passwordStrengthColor = orangeAccent;
      } else {
        passwordStrengthText = "Strong";
        passwordStrengthColor = greenAccent;
      }
    });
  }

  bool _validatePassword(String password) {
    if (password.isEmpty) {
      setState(() => passwordError = "Password is required");
      return false;
    }
    if (password.length < 8) {
      setState(() => passwordError = "Password must be at least 8 characters");
      return false;
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      setState(() => passwordError = "Password must contain an uppercase letter");
      return false;
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      setState(() => passwordError = "Password must contain a lowercase letter");
      return false;
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      setState(() => passwordError = "Password must contain a number");
      return false;
    }
    setState(() => passwordError = null);
    return true;
  }

  bool _validateConfirmPassword(String confirmPassword) {
    if (confirmPassword.isEmpty) {
      setState(() => confirmPasswordError = "Please confirm your password");
      return false;
    }
    if (confirmPassword != passwordController.text) {
      setState(() => confirmPasswordError = "Passwords do not match");
      return false;
    }
    setState(() => confirmPasswordError = null);
    return true;
  }

  bool _validateStep1() {
    bool isFirstNameValid = _validateFirstName(firstNameController.text.trim());
    bool isLastNameValid = _validateLastName(lastNameController.text.trim());
    bool isPhoneValid = _validatePhone(phoneController.text.trim());
    
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your date of birth'),
          backgroundColor: redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
    
    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select your gender'),
          backgroundColor: redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
    
    return isFirstNameValid && isLastNameValid && isPhoneValid;
  }

  bool _validateStep2() {
    bool isEmailValid = _validateEmail(emailController.text.trim());
    bool isPasswordValid = _validatePassword(passwordController.text);
    bool isConfirmPasswordValid = _validateConfirmPassword(confirmPasswordController.text);
    
    if (!agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please agree to the Terms & Conditions'),
          backgroundColor: redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
    
    return isEmailValid && isPasswordValid && isConfirmPasswordValid;
  }

  void _handleNextStep() {
    HapticFeedback.mediumImpact();
    
    if (currentStep == 0) {
      if (_validateStep1()) {
        setState(() => currentStep = 1);
      }
    } else {
      _handleSignUp();
    }
  }

  void _handlePreviousStep() {
    HapticFeedback.lightImpact();
    if (currentStep > 0) {
      setState(() => currentStep = 0);
    } else {
      Navigator.pop(context);
    }
  }

 Future<void> _handleSignUp() async {
  if (_validateStep2()) {
    setState(() => isLoading = true);

    // Format date as YYYY-MM-DD
    String? dateOfBirth;
    if (selectedDate != null) {
      dateOfBirth = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
    }

    // Call API
    final result = await ApiService.register(
      email: emailController.text.trim(),
      password: passwordController.text,
      firstName: firstNameController.text.trim(),
      lastName: lastNameController.text.trim(),
      phone: '$_selectedCountryCode${phoneController.text.trim()}',
      dateOfBirth: dateOfBirth,
      gender: selectedGender?.toLowerCase(),
    );

    setState(() => isLoading = false);

    if (mounted) {
      if (result['success']) {
        // Navigate to OTP verification
        Navigator.pushReplacementNamed(
          context,
          '/otp-verification',
          arguments: {
            'email': emailController.text.trim(),
            'type': 'signup',
          },
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Registration failed'),
            backgroundColor: redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: darkCard,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: r.h(20)),
                          _buildProgressIndicator(r),
                          SizedBox(height: r.h(30)),
                          _buildStepTitle(r),
                          SizedBox(height: r.h(24)),
                          _buildForm(r),
                          SizedBox(height: r.h(30)),
                          if (currentStep == 1) _buildSocialSection(r),
                          SizedBox(height: r.h(30)),
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
          top: r.h(-100),
          right: r.w(-60),
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(_floatingController.value * math.pi) * r.w(15),
                  _floatingController.value * r.h(30),
                ),
                child: Container(
                  width: r.dp(250),
                  height: r.dp(250),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        currentStep == 0 ? softLavender : mintGreen,
                        (currentStep == 0 ? softLavender : mintGreen).withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: r.h(-80),
          left: r.w(-50),
          child: AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  -math.cos(_floatingController.value * math.pi) * r.w(20),
                  -_floatingController.value * r.h(40),
                ),
                child: Container(
                  width: r.dp(220),
                  height: r.dp(220),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        currentStep == 0 ? mintGreen : creamBeige,
                        (currentStep == 0 ? mintGreen : creamBeige).withOpacity(0.2),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handlePreviousStep,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Step ${currentStep + 1} of 2",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Responsive r) {
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            decoration: BoxDecoration(
              color: currentStep >= 1 ? darkCard : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTitle(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentStep == 0 ? "Personal Information" : "Account Details",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          currentStep == 0
              ? "Tell us a bit about yourself"
              : "Create your secure account",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(Responsive r) {
    return Container(
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
        children: [
          if (currentStep == 0) ...[
            // First Name & Last Name Row
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: "First Name",
                    hint: "John",
                    icon: Icons.person_outline_rounded,
                    controller: firstNameController,
                    focusNode: firstNameFocus,
                    errorText: firstNameError,
                    onChanged: (v) {
                      if (firstNameError != null) _validateFirstName(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    label: "Last Name",
                    hint: "Doe",
                    icon: Icons.person_outline_rounded,
                    controller: lastNameController,
                    focusNode: lastNameFocus,
                    errorText: lastNameError,
                    onChanged: (v) {
                      if (lastNameError != null) _validateLastName(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            
            // Phone Number with Country Code
            _buildPhoneField(),
            const SizedBox(height: 18),
            
            // Date of Birth
            _buildDatePicker(),
            const SizedBox(height: 18),
            
            // Gender Selection
            _buildGenderSelector(),
          ] else ...[
            // Email
            _buildInputField(
              label: "Email Address",
              hint: "your.email@example.com",
              icon: Icons.email_outlined,
              controller: emailController,
              focusNode: emailFocus,
              errorText: emailError,
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) {
                if (emailError != null) _validateEmail(v);
              },
            ),
            const SizedBox(height: 18),
            
            // Password
            _buildInputField(
              label: "Password",
              hint: "Create a strong password",
              icon: Icons.lock_outline_rounded,
              controller: passwordController,
              focusNode: passwordFocus,
              errorText: passwordError,
              isPassword: true,
              showPassword: showPassword,
              onTogglePassword: () => setState(() => showPassword = !showPassword),
              onChanged: (v) {
                _checkPasswordStrength(v);
                if (passwordError != null) _validatePassword(v);
              },
            ),
            
            // Password Strength Indicator
            if (passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPasswordStrengthIndicator(),
            ],
            const SizedBox(height: 18),
            
            // Confirm Password
            _buildInputField(
              label: "Confirm Password",
              hint: "Re-enter your password",
              icon: Icons.lock_outline_rounded,
              controller: confirmPasswordController,
              focusNode: confirmPasswordFocus,
              errorText: confirmPasswordError,
              isPassword: true,
              showPassword: showConfirmPassword,
              onTogglePassword: () => setState(() => showConfirmPassword = !showConfirmPassword),
              onChanged: (v) {
                if (confirmPasswordError != null) _validateConfirmPassword(v);
              },
            ),
            const SizedBox(height: 20),
            
            // Terms & Conditions
            _buildTermsCheckbox(),
          ],
          
          const SizedBox(height: 28),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required FocusNode focusNode,
    String? errorText,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onTogglePassword,
    Function(String)? onChanged,
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? redAccent.withOpacity(0.5)
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
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.25),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: errorText != null ? redAccent : Colors.black.withOpacity(0.4),
                size: 20,
              ),
              suffixIcon: isPassword
                  ? GestureDetector(
                      onTap: onTogglePassword,
                      child: Icon(
                        showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: Colors.black.withOpacity(0.4),
                        size: 20,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: redAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText,
                  style: TextStyle(color: redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Date of Birth",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.black.withOpacity(0.4),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                        : "Select your birth date",
                    style: TextStyle(
                      color: selectedDate != null
                          ? Colors.black87
                          : Colors.black.withOpacity(0.25),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.black.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gender",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildGenderOption("Male", Icons.male_rounded),
            const SizedBox(width: 12),
            _buildGenderOption("Female", Icons.female_rounded),
            const SizedBox(width: 12),
            _buildGenderOption("Other", Icons.transgender_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => selectedGender = gender);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? darkCard : bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? darkCard : Colors.black.withOpacity(0.06),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black.withOpacity(0.4),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                gender,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Phone Number",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: phoneError != null
                  ? redAccent.withOpacity(0.5)
                  : Colors.black.withOpacity(0.06),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Country Code Dropdown
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.black.withOpacity(0.06)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCountryFlag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCountryCode,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              ),
              // Phone Input
              Expanded(
                child: TextField(
                  controller: phoneController,
                  focusNode: phoneFocus,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) {
                    if (phoneError != null) _validatePhone(v);
                  },
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: "300 1234567",
                    hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.25),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (phoneError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 14, color: redAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  phoneError!,
                  style: TextStyle(color: redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _CountryPickerSheet(
          countryCodes: _countryCodes,
          selectedCode: _selectedCountryCode,
          selectedFlag: _selectedCountryFlag,
          onSelected: (code, flag) {
            setState(() {
              _selectedCountryCode = code;
              _selectedCountryFlag = flag;
            });
          },
        );
      },
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(6, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 5 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: index < passwordStrength
                            ? passwordStrengthColor
                            : Colors.black.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              passwordStrengthText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: passwordStrengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Use 8+ characters with uppercase, lowercase, numbers & symbols",
          style: TextStyle(
            fontSize: 11,
            color: Colors.black.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => agreeToTerms = !agreeToTerms);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: agreeToTerms ? darkCard : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: agreeToTerms ? darkCard : Colors.black.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: agreeToTerms
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            children: [
              Text(
                "I agree to the ",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showTermsDialog();
                },
                child: const Text(
                  "Terms & Conditions",
                  style: TextStyle(
                    fontSize: 13,
                    color: blueAccent,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: blueAccent,
                  ),
                ),
              ),
              Text(
                " and ",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showPrivacyPolicyDialog();
                },
                child: const Text(
                  "Privacy Policy",
                  style: TextStyle(
                    fontSize: 13,
                    color: blueAccent,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
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
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTermsSection(
                        '1. Medical Disclaimer',
                        'NeuroVerse is a digital health screening tool designed to assist in the early detection of neurological conditions including Alzheimer\'s disease and Parkinson\'s disease.\n\n'
                        '⚠️ IMPORTANT: This application does NOT provide medical diagnosis. All results generated by our AI algorithms are preliminary assessments and must be reviewed and confirmed by qualified healthcare professionals.\n\n'
                        'Never disregard professional medical advice or delay seeking treatment based on results from this application.',
                        Icons.medical_services_outlined,
                        const Color(0xFFEF4444),
                      ),
                      _buildTermsSection(
                        '2. Health Data Collection',
                        'By using NeuroVerse, you consent to the collection and processing of the following health-related data:\n\n'
                        '• Speech & Language Patterns: Voice recordings, speech fluency, pause analysis\n'
                        '• Motor Function Data: Tremor measurements, drawing patterns, tap accuracy\n'
                        '• Cognitive Assessment Results: Memory tests, reaction times, attention scores\n'
                        '• Facial Analysis Data: Expression patterns, blink rates, muscle movements\n'
                        '• Digital Wellness Metrics: Screen time, app usage patterns',
                        Icons.health_and_safety_outlined,
                        const Color(0xFF3B82F6),
                      ),
                      _buildTermsSection(
                        '3. AI & Machine Learning',
                        'Our AI models are trained on clinical datasets and use the following approaches:\n\n'
                        '• Deep Learning: Neural networks analyze multimodal biomarkers\n'
                        '• Explainable AI (XAI): SHAP values and saliency maps provide transparency\n'
                        '• Continuous Learning: Models are updated with anonymized clinical data\n\n'
                        'AI predictions have inherent limitations. Sensitivity: 87%, Specificity: 92% based on validation studies. These metrics may vary across populations.',
                        Icons.psychology_outlined,
                        const Color(0xFF8B5CF6),
                      ),
                      _buildTermsSection(
                        '4. Research Participation',
                        'Your anonymized data may contribute to neurodegenerative disease research:\n\n'
                        '• Data is de-identified using industry-standard methods\n'
                        '• Research aims to improve early detection algorithms\n'
                        '• Partnerships with accredited medical institutions\n'
                        '• You may opt-out at any time without affecting app functionality\n\n'
                        'Research participation is optional and can be managed in Privacy Settings.',
                        Icons.science_outlined,
                        const Color(0xFF10B981),
                      ),
                      _buildTermsSection(
                        '5. User Responsibilities',
                        'As a user of NeuroVerse, you agree to:\n\n'
                        '• Provide accurate personal and health information\n'
                        '• Complete assessments as instructed for reliable results\n'
                        '• Use the app only for its intended health screening purpose\n'
                        '• Not share your account credentials with others\n'
                        '• Report any technical issues or inaccurate results\n'
                        '• Seek professional medical advice for any health concerns',
                        Icons.verified_user_outlined,
                        const Color(0xFFF59E0B),
                      ),
                      _buildTermsSection(
                        '6. Limitation of Liability',
                        'NeuroVerse and its developers, partners, and affiliates:\n\n'
                        '• Are NOT liable for any medical decisions made based on app results\n'
                        '• Do not guarantee the accuracy of AI predictions\n'
                        '• Provide the app "as is" without warranties of any kind\n'
                        '• Are not responsible for delays in seeking proper medical care\n\n'
                        'Maximum liability is limited to the amount paid for the service.',
                        Icons.gavel_outlined,
                        const Color(0xFF6B7280),
                      ),
                      _buildTermsSection(
                        '7. Updates & Modifications',
                        'We reserve the right to:\n\n'
                        '• Update these terms with 30 days notice via email\n'
                        '• Modify app features and functionality\n'
                        '• Update AI models and algorithms\n'
                        '• Change pricing with reasonable notice\n\n'
                        'Continued use after changes constitutes acceptance.',
                        Icons.update_outlined,
                        const Color(0xFFEC4899),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withOpacity(0.1)),
                        ),
                        child: const Center(
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => agreeToTerms = true);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: darkCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'I Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.policy_outlined,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
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
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HIPAA Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                          ),
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
                                Icons.verified_user_rounded,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HIPAA Compliant',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Your health data is protected under medical privacy standards',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      _buildTermsSection(
                        '1. Information We Collect',
                        'Personal Information:\n'
                        '• Name, email address, phone number\n'
                        '• Date of birth, gender\n'
                        '• Profile photo (optional)\n\n'
                        'Health & Medical Data:\n'
                        '• Neurological assessment results\n'
                        '• Risk scores and AI predictions\n'
                        '• Voice recordings for speech analysis\n'
                        '• Motor function test data\n'
                        '• Cognitive test performance\n\n'
                        'Device & Usage Data:\n'
                        '• Device type, operating system\n'
                        '• App usage analytics\n'
                        '• Screen time metrics (with permission)',
                        Icons.folder_outlined,
                        const Color(0xFF3B82F6),
                      ),
                      _buildTermsSection(
                        '2. How We Use Your Data',
                        'Primary Uses:\n'
                        '• Generate personalized health risk assessments\n'
                        '• Track your neurological health over time\n'
                        '• Provide AI-powered insights and recommendations\n'
                        '• Send important health notifications\n\n'
                        'Secondary Uses:\n'
                        '• Improve AI detection algorithms (anonymized)\n'
                        '• Conduct medical research (with consent)\n'
                        '• Provide customer support\n'
                        '• Comply with legal requirements',
                        Icons.analytics_outlined,
                        const Color(0xFF8B5CF6),
                      ),
                      _buildTermsSection(
                        '3. Data Storage & Security',
                        'Encryption:\n'
                        '• Data in transit: TLS 1.3 encryption\n'
                        '• Data at rest: AES-256 encryption\n'
                        '• Voice recordings: End-to-end encrypted\n\n'
                        'Infrastructure:\n'
                        '• HIPAA-compliant cloud servers\n'
                        '• Regular security audits\n'
                        '• Multi-factor authentication\n'
                        '• Automatic session timeout\n\n'
                        'Retention:\n'
                        '• Active accounts: Data retained during subscription\n'
                        '• Deleted accounts: Data purged within 30 days\n'
                        '• Research data: Permanently anonymized',
                        Icons.security_outlined,
                        const Color(0xFF10B981),
                      ),
                      _buildTermsSection(
                        '4. Data Sharing',
                        '🚫 We Do NOT:\n'
                        '• Sell your personal data to third parties\n'
                        '• Share identifiable health data without consent\n'
                        '• Use data for targeted advertising\n\n'
                        '✅ We May Share With:\n'
                        '• Your healthcare providers (with explicit consent)\n'
                        '• Research institutions (anonymized data only)\n'
                        '• Legal authorities (when required by law)\n'
                        '• Service providers (under strict contracts)',
                        Icons.share_outlined,
                        const Color(0xFFF59E0B),
                      ),
                      _buildTermsSection(
                        '5. Your Privacy Rights',
                        'You have the right to:\n\n'
                        '📥 Access: Request a copy of all your data\n'
                        '✏️ Correct: Update or fix inaccurate information\n'
                        '🗑️ Delete: Request permanent data deletion\n'
                        '📤 Export: Download your health records\n'
                        '🚫 Opt-out: Decline research participation\n'
                        '🔒 Restrict: Limit how we use your data\n\n'
                        'To exercise these rights, contact privacy@neuroverse.pk',
                        Icons.privacy_tip_outlined,
                        const Color(0xFFEC4899),
                      ),
                      _buildTermsSection(
                        '6. Children\'s Privacy',
                        'NeuroVerse is intended for users 18 years and older.\n\n'
                        'For users aged 13-17:\n'
                        '• Parental/guardian consent is required\n'
                        '• Limited data collection applies\n'
                        '• No research participation allowed\n\n'
                        'We do not knowingly collect data from children under 13.',
                        Icons.child_care_outlined,
                        const Color(0xFF6B7280),
                      ),
                      _buildTermsSection(
                        '7. Contact Us',
                        'For privacy concerns or data requests:\n\n'
                        '📧 Email: privacy@neuroverse.pk\n'
                        '📞 Phone: +92 300 1234567\n'
                        '🏢 Address: Islamabad, Pakistan\n\n'
                        'We respond to all privacy requests within 30 days.',
                        Icons.contact_support_outlined,
                        const Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black.withOpacity(0.1)),
                        ),
                        child: const Center(
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => agreeToTerms = true);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: darkCard,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'I Accept',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.6),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: isLoading ? null : _handleNextStep,
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
              ? const LoadingBars(color: Colors.white, height: 20)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentStep == 0 ? "Continue" : "Create Account",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      currentStep == 0 ? Icons.arrow_forward_rounded : Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSocialSection(Responsive r) {
    return Column(
      children: [
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
                "Or sign up with",
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
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(child: _buildGoogleLogo(), onTap: () {}),
            const SizedBox(width: 16),
            _buildSocialButton(
              child: const Icon(Icons.apple_rounded, color: Colors.white, size: 28),
              backgroundColor: Colors.black,
              onTap: () {},
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              child: const Text('f', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              backgroundColor: const Color(0xFF1877F2),
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: darkCard, width: 2)),
                ),
                child: const Text(
                  "Sign In",
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
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget child,
    Color backgroundColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: backgroundColor == Colors.white
              ? Border.all(color: Colors.black.withOpacity(0.08), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: backgroundColor == Colors.white
                  ? Colors.black.withOpacity(0.04)
                  : backgroundColor.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
}

// Google Logo Painter
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
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
    
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius - 2, center.dy),
      bluePaint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CountryPickerSheet extends StatefulWidget {
  final List<Map<String, String>> countryCodes;
  final String selectedCode;
  final String selectedFlag;
  final Function(String code, String flag) onSelected;

  const _CountryPickerSheet({
    required this.countryCodes,
    required this.selectedCode,
    required this.selectedFlag,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _search = '';

  List<Map<String, String>> get _filtered {
    if (_search.isEmpty) return widget.countryCodes;
    final q = _search.toLowerCase();
    return widget.countryCodes.where((c) =>
      c['name']!.toLowerCase().contains(q) ||
      c['code']!.contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Select Country",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: "Search country...",
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.3)),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.black.withOpacity(0.4)),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final country = _filtered[index];
                  final isSelected = country['code'] == widget.selectedCode &&
                      country['flag'] == widget.selectedFlag;
                  return ListTile(
                    leading: Text(
                      country['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      country['name']!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Text(
                      country['code']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF10B981) : Colors.black54,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF10B981).withOpacity(0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () {
                      widget.onSelected(country['code']!, country['flag']!);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}