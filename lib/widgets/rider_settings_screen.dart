import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import '../../services/auth_service.dart';

// Cloudinary configuration
const String _cloudinaryCloudName = 'dwtsrai20';
const String _cloudinaryUploadPreset = 'user_profile_upload';

class RiderSettingsScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String profileImageUrl;
  final Function(String) onNameChanged;
  final Function(String) onImageChanged;
  final Function(String) onEmailChanged;
  final String riderId;

  const RiderSettingsScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.profileImageUrl,
    required this.onNameChanged,
    required this.onImageChanged,
    required this.onEmailChanged,
    required this.riderId,
  });

  @override
  State<RiderSettingsScreen> createState() => _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends State<RiderSettingsScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  String? _newProfileImageUrl;
  String? _tempName;
  String _displayEmail = 'Loading email...';
  bool _isLoadingEmail = true;
  final AuthService _authService = AuthService();
  final _cloudinary = CloudinaryPublic(_cloudinaryCloudName, _cloudinaryUploadPreset, cache: false);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isUploading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _nameController = TextEditingController(text: widget.userName);
    _newProfileImageUrl = widget.profileImageUrl;
    _tempName = widget.userName;
    _fetchInitialEmail();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialEmail() async {
    print('DEBUG: Starting _fetchInitialEmail at ${DateTime.now()}');
    setState(() {
      _isLoadingEmail = true;
      _displayEmail = 'Loading email...';
    });

    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _displayEmail = 'Not authenticated';
          _isLoadingEmail = false;
        });
        print('DEBUG: No authenticated user found');
      }
      return;
    }
    print('DEBUG: Authenticated user UID: ${user.uid}, email from auth: ${user.email}');

    try {
      final profile = await _fetchUserProfile(widget.riderId).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timed out while fetching user profile');
        },
      );

      if (mounted) {
        setState(() {
          _nameController.text = profile['name'] ?? widget.userName;
          _tempName = _nameController.text;
          _newProfileImageUrl = profile['profileImageUrl'] ?? widget.profileImageUrl;
          _displayEmail = profile['email'] ?? user.email ?? widget.userEmail;
          _isLoadingEmail = false;
        });
        widget.onNameChanged(_nameController.text);
        widget.onImageChanged(_newProfileImageUrl ?? widget.profileImageUrl);
        widget.onEmailChanged(_displayEmail);
        print('DEBUG: Profile fetched successfully at ${DateTime.now()} - Email: $_displayEmail');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayEmail = user.email ?? widget.userEmail;
          _isLoadingEmail = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
        print('DEBUG: Error fetching profile at ${DateTime.now()}: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile(String uid) async {
    print('DEBUG: Fetching rider profile from Firestore for UID: $uid');
    try {
      final doc = await _firestore.collection('rider').doc(uid).get();
      print('DEBUG: Firestore document exists: ${doc.exists}');
      if (doc.exists) {
        final data = doc.data() ?? {};
        print('DEBUG: Firestore document data: $data');
        return {
          'name': data['name'] as String? ?? widget.userName,
          'email': data['email'] as String?,
          'profileImageUrl': data['profileImageUrl'] as String? ?? widget.profileImageUrl,
        };
      } else {
        print('DEBUG: Rider document does not exist, creating default profile');
        await _createDefaultProfile(uid);
        final newDoc = await _firestore.collection('rider').doc(uid).get();
        final newData = newDoc.data() ?? {};
        print('DEBUG: Newly created document data: $newData');
        return {
          'name': newData['name'] as String? ?? widget.userName,
          'email': newData['email'] as String?,
          'profileImageUrl': newData['profileImageUrl'] as String? ?? widget.profileImageUrl,
        };
      }
    } catch (e) {
      print('DEBUG: Error in _fetchUserProfile: $e');
      rethrow;
    }
  }

  Future<void> _createDefaultProfile(String uid) async {
    try {
      final user = _authService.currentUser;
      if (user != null && mounted) {
        print('DEBUG: Creating default profile for UID: ${user.uid}');
        await _firestore.collection('rider').doc(uid).set({
          'riderId': uid,
          'email': user.email ?? widget.userEmail, // Use user.email or widget.userEmail
          'name': widget.userName,
          'profileImageUrl': widget.profileImageUrl,
        }, SetOptions(merge: true));
        print('DEBUG: Default profile created with email: ${user.email ?? widget.userEmail}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create profile: $e')),
        );
        print('DEBUG: Error creating profile: $e');
      }
      throw e;
    }
  }

  Future<void> _saveUserProfile(String uid, String name, String? imageUrl) async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        print('DEBUG: Saving profile for UID: ${user.uid}, Name: $name, ImageUrl: $imageUrl');
        await _firestore.collection('rider').doc(uid).set({
          'name': name,
          'profileImageUrl': imageUrl ?? _newProfileImageUrl ?? widget.profileImageUrl,
          'email': user.email ?? widget.userEmail, // Update email if available
        }, SetOptions(merge: true));
        print('DEBUG: Profile saved successfully');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
        print('DEBUG: Error saving profile: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          pickedFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      if (mounted) {
        setState(() {
          _newProfileImageUrl = response.secureUrl;
          _isUploading = false;
        });
        final user = _authService.currentUser;
        if (user != null) {
          await _saveUserProfile(user.uid, _tempName ?? widget.userName, _newProfileImageUrl);
          widget.onImageChanged(_newProfileImageUrl!);
          print('DEBUG: Image uploaded and profile updated with URL: ${_newProfileImageUrl}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        print('DEBUG: Error uploading image: $e');
      }
    }
  }

  Future<void> _showSaveConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surfaceColor,
          title: Text('Save Changes', style: AppStyles.headline2),
          content: Text(
            'Are you sure you want to save your profile changes?',
            style: AppStyles.bodyText1,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: Text('Cancel', style: AppStyles.bodyText1),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Save', style: AppStyles.bodyText1.copyWith(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                _saveChanges();
              },
            ),
          ],
        );
      },
    );
  }

  void _saveChanges() {
    if (_tempName == null || _tempName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid name'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    try {
      final user = _authService.currentUser;
      if (user != null) {
        _saveUserProfile(user.uid, _tempName!, _newProfileImageUrl);
        widget.onNameChanged(_tempName!);
        if (_newProfileImageUrl != null) {
          widget.onImageChanged(_newProfileImageUrl!);
        }
        widget.onEmailChanged(_displayEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        print('DEBUG: Profile changes saved - Name: $_tempName, Email: $_displayEmail, ImageUrl: $_newProfileImageUrl');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save changes: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      print('DEBUG: Error saving changes: $e');
    }
  }

  void _copyEmailToClipboard() {
    Clipboard.setData(ClipboardData(text: _displayEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Rider Settings', style: AppStyles.headline1),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 4,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Stack(
                            key: ValueKey(_newProfileImageUrl),
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primaryColor, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: AppColors.primaryColor,
                                    backgroundImage: _newProfileImageUrl != null &&
                                        _newProfileImageUrl!.isNotEmpty &&
                                        _newProfileImageUrl != 'https://via.placeholder.com/150'
                                        ? NetworkImage(_newProfileImageUrl!)
                                        : null,
                                    child: _newProfileImageUrl == null ||
                                        _newProfileImageUrl!.isEmpty ||
                                        _newProfileImageUrl == 'https://via.placeholder.com/150'
                                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploading ? null : _pickImage,
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.surfaceColor,
                                    child: _isUploading
                                        ? const CircularProgressIndicator(strokeWidth: 2)
                                        : const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _tempName ?? widget.userName,
                          style: AppStyles.headline2,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile Name',
                  style: AppStyles.headline3,
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Enter your name',
                      hintStyle: AppStyles.bodyText2,
                      prefixIcon: const Icon(Icons.person, color: AppColors.primaryColor),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: AppStyles.bodyText1,
                    onChanged: (value) => setState(() => _tempName = value.trim()),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTapDown: (_) => _animationController.forward(),
                    onTapUp: (_) => _animationController.reverse(),
                    onTapCancel: () => _animationController.reverse(),
                    onTap: _isUploading ? null : _showSaveConfirmationDialog,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.gradientStart, AppColors.gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Save Changes',
                          style: AppStyles.bodyText1.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Email',
                  style: AppStyles.headline3,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _displayEmail,
                          style: AppStyles.bodyText1,
                          semanticsLabel: 'Email: $_displayEmail',
                        ),
                      ),
                      if (!_isLoadingEmail && (_displayEmail == 'Failed to load email' || _displayEmail == 'Not authenticated'))
                        GestureDetector(
                          onTap: _fetchInitialEmail,
                          child: const Icon(
                            Icons.refresh,
                            color: AppColors.primaryColor,
                            size: 20,
                          ),
                        ),
                      if (!_isLoadingEmail && _displayEmail.contains('@'))
                        GestureDetector(
                          onTap: _copyEmailToClipboard,
                          child: const Icon(
                            Icons.copy,
                            color: AppColors.primaryColor,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}