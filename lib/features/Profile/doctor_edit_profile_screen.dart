import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:image_picker/image_picker.dart';

class DoctorEditProfileScreen extends StatefulWidget {
  const DoctorEditProfileScreen({super.key});

  @override
  State<DoctorEditProfileScreen> createState() => _DoctorEditProfileScreenState();
}

class _DoctorEditProfileScreenState extends State<DoctorEditProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isLoadingData = true;
  
  // Editable fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _yearsExpController = TextEditingController();
  
  // Non-editable info
  String _email = '';
  String _licenseNumber = '';
  String _specialization = '';
  String _memberSince = '';
  String _status = '';
  String? _profileImagePath;

  // Clinical color palette
  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color softTeal = Color(0xFFCCFBF1);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color softCyan = Color(0xFFCFFAFE);
  static const Color softSlate = Color(0xFFE2E8F0);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    
    _loadDoctorData();
    
    // Listen for changes
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _hospitalController.addListener(_onFieldChanged);
    _departmentController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _yearsExpController.addListener(_onFieldChanged);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _hospitalController.dispose();
    _departmentController.dispose();
    _bioController.dispose();
    _yearsExpController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorData() async {
    final result = await ApiService.getDoctorProfile();
    
    if (mounted && result['success']) {
      final data = result['data'];
      
      setState(() {
        _firstNameController.text = data['first_name'] ?? '';
        _lastNameController.text = data['last_name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _hospitalController.text = data['hospital_affiliation'] ?? '';
        _departmentController.text = data['department'] ?? '';
        _bioController.text = data['bio'] ?? '';
        _yearsExpController.text = (data['years_of_experience'] ?? 0).toString();
        
        _profileImagePath = data['profile_image_path'];
        _email = data['email'] ?? '';
        _licenseNumber = data['license_number'] ?? '';
        _specialization = data['specialization'] ?? '';
        _status = data['status'] ?? 'active';
        
        if (data['created_at'] != null) {
          final date = DateTime.parse(data['created_at']);
          _memberSince = '${_monthName(date.month)} ${date.year}';
        }
        
        _isLoadingData = false;
        _hasChanges = false;
      });
    } else {
      setState(() => _isLoadingData = false);
    }
  }

  String _monthName(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _formatSpecialization(String spec) {
    return spec.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _pickImage(bool fromCamera) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      
      // Use doctor-specific upload endpoint
      final result = await ApiService.uploadProfileImage(bytes, picked.name);

      if (mounted && result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text("Profile picture updated!"),
              ],
            ),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadDoctorData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Upload failed"),
            backgroundColor: errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Update Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: primaryTeal,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(true);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: accentCyan,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(false);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_profileImagePath != null && _profileImagePath!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfileImage();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: errorRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: errorRed, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Remove Photo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: errorRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeProfileImage() async {
    final result = await ApiService.removeProfileImage();
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile picture removed"),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadDoctorData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? "Failed to remove"),
            backgroundColor: errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    // Parse years of experience
    int yearsExp = 0;
    try {
      yearsExp = int.parse(_yearsExpController.text.trim());
    } catch (_) {}
    
    final result = await ApiService.updateDoctorProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      hospitalAffiliation: _hospitalController.text.trim(),
      department: _departmentController.text.trim(),
      bio: _bioController.text.trim(),
    );
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Update failed'),
            backgroundColor: errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _discardChanges() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Discard Changes?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Keep Editing',
                style: TextStyle(color: Colors.black.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                'Discard',
                style: TextStyle(color: errorRed, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryTeal),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _discardChanges();
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 30),
                      _buildProfileAvatar(),
                      const SizedBox(height: 30),
                      _buildPersonalInfoCard(),
                      const SizedBox(height: 20),
                      _buildProfessionalInfoCard(),
                      const SizedBox(height: 20),
                      _buildBioCard(),
                      const SizedBox(height: 20),
                      _buildNonEditableCard(),
                      const SizedBox(height: 30),
                      _buildSaveButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              onTap: _discardChanges,
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
                  Icons.close_rounded,
                  size: 22,
                  color: Colors.black87,
                ),
              ),
            ),
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _status == 'active' ? softTeal : warningAmber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _status == 'active' ? successGreen : warningAmber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _status == 'active' ? 'Active' : _status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _status == 'active' ? successGreen : warningAmber,
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

  Widget _buildProfileAvatar() {
    final firstName = _firstNameController.text;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'D';

    return _buildAnimatedWidget(
      delay: 0.05,
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
                  child: (_profileImagePath != null && _profileImagePath!.isNotEmpty)
                      ? Image.network(
                          "${ApiService.baseUrl}/$_profileImagePath",
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
              // Edit button
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryTeal,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: bgColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: primaryTeal.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tap camera to change photo',
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

  Widget _buildPersonalInfoCard() {
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: softTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_rounded, color: primaryTeal, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      label: 'First Name',
                      controller: _firstNameController,
                      icon: Icons.badge_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildEditableField(
                      label: 'Last Name',
                      controller: _lastNameController,
                      icon: Icons.badge_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildEditableField(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoCard() {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: softCyan,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.work_rounded, color: accentCyan, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Professional Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildEditableField(
                label: 'Hospital/Clinic Affiliation',
                controller: _hospitalController,
                icon: Icons.local_hospital_rounded,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildEditableField(
                      label: 'Department',
                      controller: _departmentController,
                      icon: Icons.business_rounded,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildEditableField(
                      label: 'Years Exp.',
                      controller: _yearsExpController,
                      icon: Icons.timeline_rounded,
                      keyboardType: TextInputType.number,
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

  Widget _buildBioCard() {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF6366F1), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Bio / About',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: TextField(
                  controller: _bioController,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a brief description about yourself, your expertise, and specializations...',
                    hintStyle: TextStyle(
                      color: Colors.black.withOpacity(0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will be visible to patients and other healthcare providers',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                size: 20,
                color: primaryTeal.withOpacity(0.6),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNonEditableCard() {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: softSlate,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_rounded, color: Colors.black54, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Verified Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Contact admin to update these fields',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _email,
                isVerified: true,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.badge_outlined,
                label: 'License Number',
                value: _licenseNumber.isNotEmpty ? _licenseNumber : 'Not set',
                isVerified: _licenseNumber.isNotEmpty,
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.medical_services_outlined,
                label: 'Specialization',
                value: _formatSpecialization(_specialization),
              ),
              _buildDivider(),
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Member Since',
                value: _memberSince.isNotEmpty ? _memberSince : 'N/A',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isVerified = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: Colors.black.withOpacity(0.5)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: successGreen),
                            const SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Colors.black.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.black.withOpacity(0.06),
      height: 1,
    );
  }

  Widget _buildSaveButton() {
    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: _hasChanges && !_isLoading ? _saveChanges : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: _hasChanges
                  ? LinearGradient(
                      colors: [darkCard, darkCard.withOpacity(0.9)],
                    )
                  : null,
              color: _hasChanges ? null : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              boxShadow: _hasChanges
                  ? [
                      BoxShadow(
                        color: darkCard.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryTeal),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.save_rounded,
                          color: _hasChanges ? Colors.white : Colors.black.withOpacity(0.3),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Save Changes',
                          style: TextStyle(
                            color: _hasChanges ? Colors.white : Colors.black.withOpacity(0.3),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
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