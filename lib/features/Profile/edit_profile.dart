import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
  bool _isLoading = false;
  bool _hasChanges = false;
  
  final TextEditingController _firstNameController = TextEditingController();
final TextEditingController _lastNameController = TextEditingController();
final TextEditingController _phoneController = TextEditingController();
final TextEditingController _locationController = TextEditingController();
  
  // Non-editable info (loaded from API)
  String _email = '';
  String _dob = '';
  String _gender = '';
  String _memberSince = '';
  bool _isLoadingData = true;

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  File? _selectedImage;
  String? _profileImagePath;


  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadUserData();
    // Listen for changes
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);

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
  Future<void> _pickImage(bool fromCamera) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 80, // AUTO RESOLUTION COMPRESSION
  );

  if (picked != null) {
    // Read bytes from picked image (works on web and mobile)
    final bytes = await picked.readAsBytes();
    
    final result = await ApiService.uploadProfileImage(bytes, picked.name);

    if (mounted && result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated!")),
      );
      _loadUserData(); // Refresh UI
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? "Upload failed")),
      );
    }
  }
}


  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }
// Add this new method:
Future<void> _loadUserData() async {
  final result = await ApiService.getUserProfile();
 
  if (mounted && result['success']) {
    final data = result['data'];
    

    setState(() {
      _firstNameController.text = data['first_name'] ?? '';
      _lastNameController.text = data['last_name'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _profileImagePath = data['profile_image_path'];
      _email = data['email'] ?? '';
      _gender = data['gender'] ?? '';
      
      // Format date of birth
      if (data['date_of_birth'] != null) {
        _dob = data['date_of_birth'];
      }
      
      // Format member since
      if (data['created_at'] != null) {
        final date = DateTime.parse(data['created_at']);
        _memberSince = '${_monthName(date.month)} ${date.year}';
      }
      
      _isLoadingData = false;
      _hasChanges = false;  // Reset after loading
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
  Future<void> _saveChanges() async {
  if (!_hasChanges) return;
  
  HapticFeedback.mediumImpact();
  setState(() => _isLoading = true);
  
  // Call API
  final result = await ApiService.updateProfile(
    firstName: _firstNameController.text.trim(),
    lastName: _lastNameController.text.trim(),
    phone: _phoneController.text.trim(),
  );
  
  setState(() => _isLoading = false);
  
  if (mounted) {
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Profile updated successfully!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: greenAccent,
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
          backgroundColor: redAccent,
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
              child: const Text(
                'Discard',
                style: TextStyle(color: redAccent, fontWeight: FontWeight.w600),
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
    // Add loading check FIRST
  if (_isLoadingData) {
    return Scaffold(
      backgroundColor: bgColor,
      body: const Center(
        child: CircularProgressIndicator(),
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
              const SizedBox(height: 20),
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildProfileAvatar(),
                      const SizedBox(height: 32),
                      
                      // Editable Section
                      _buildSectionTitle('Editable Information', Icons.edit_rounded),
                      const SizedBox(height: 16),
                      _buildEditableCard(),
                      
                      const SizedBox(height: 28),
                      
                      // Non-Editable Section
                      _buildSectionTitle('Account Information', Icons.lock_outline_rounded),
                      const SizedBox(height: 16),
                      _buildNonEditableCard(),
                      
                      const SizedBox(height: 32),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _discardChanges,
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
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Unsaved',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: blueAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Center(
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: mintGreen, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: mintGreen.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Container(
                  color: softLavender,
                 child: _selectedImage != null
    ? Image.file(_selectedImage!, fit: BoxFit.cover)
    : (_profileImagePath != null && _profileImagePath!.isNotEmpty
        ? Image.network("${ApiService.baseUrl}/${_profileImagePath!}", fit: BoxFit.cover)
        : const Icon(Icons.person_rounded, size: 60, color: Colors.white)),

                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showImagePickerOptions();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: blueAccent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Change Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: blueAccent,
                  onTap: () {
                    Navigator.pop(context);
                    // Open camera
                     _pickImage(true);
                  },
                ),
                _buildImageOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: greenAccent,
                  onTap: () {
                    Navigator.pop(context);
                    // Open gallery
                    _pickImage(false);
                  },
                ),
                _buildImageOption(
                  icon: Icons.delete_rounded,
                  label: 'Remove',
                  color: redAccent,
                  onTap: () async{
                    Navigator.pop(context);
                    // Remove photo
                    final result = await ApiService.removeProfileImage();

  if (result["success"]) {
    setState(() {
      _selectedImage = null;
      _profileImagePath = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile photo removed")),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result["error"] ?? "Failed to delete photo")),
    );
  }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
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
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableCard() {
    return _buildAnimatedWidget(
      delay: 0.1,
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
          children: [
            // First Name & Last Name Row
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'First Name',
                    controller: _firstNameController,
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    icon: Icons.person_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildInputField(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),
            _buildInputField(
              label: 'Location',
              controller: _locationController,
              icon: Icons.location_on_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
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
                color: Colors.black.withOpacity(0.4),
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
      delay: 0.15,
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
          children: [
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _email,
              isVerified: true,
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.cake_outlined,
              label: 'Date of Birth',
              value: _dob,
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Gender',
              value: _gender,
            ),
            _buildDivider(),
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Member Since',
              value: _memberSince,
            ),
          ],
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
                          color: greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 12, color: greenAccent),
                            const SizedBox(width: 3),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: greenAccent,
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
      delay: 0.2,
      child: GestureDetector(
        onTap: _hasChanges && !_isLoading ? _saveChanges : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 56,
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
                      valueColor: AlwaysStoppedAnimation<Color>(mintGreen),
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