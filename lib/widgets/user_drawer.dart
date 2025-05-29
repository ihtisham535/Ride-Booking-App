import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import '../../services/auth_service.dart';
import '../../screens/user/user_home.dart';
import 'settings_screen.dart';
import '../../screens/auth/role_selection_screen.dart';

class UserDrawer extends StatefulWidget {
  const UserDrawer({super.key});

  @override
  State<UserDrawer> createState() => _UserDrawerState();
}

class _UserDrawerState extends State<UserDrawer> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String _userName = 'Passenger User';
  String _userEmail = 'Loading...';
  String _profileImageUrl = 'https://via.placeholder.com/150';
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _selectedIndex = -1; // Track active button

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
    _authService.authStateChanges.listen((User? user) {
      if (user != null && mounted) {
        _fetchUserProfile(user.uid).then((_) {
          if (mounted) setState(() => _isLoading = false);
        }).catchError((e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load profile: $e')),
            );
          }
        });
      } else if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              (route) => false,
        );
      }
    });
    _fetchInitialUser();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? 'No email available';
      });
      await _fetchUserProfile(user.uid);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'Passenger User';
          _userEmail = doc.data()?['email'] ?? _authService.currentUser?.email ?? 'No email available';
          _profileImageUrl = doc.data()?['profileImageUrl'] ?? 'https://via.placeholder.com/150';
        });
      } else if (mounted) {
        await _createDefaultProfile(uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _createDefaultProfile(String uid) async {
    try {
      final user = _authService.currentUser;
      if (user != null && mounted) {
        final userEmail = user.email ?? 'No email available';
        await _firestore.collection('users').doc(uid).set({
          'name': 'Passenger User',
          'email': userEmail,
          'profileImageUrl': 'https://via.placeholder.com/150',
        }, SetOptions(merge: true));
        setState(() {
          _userName = 'Passenger User';
          _userEmail = userEmail;
          _profileImageUrl = 'https://via.placeholder.com/150';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create profile: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.surfaceColor,
          title: Text('Delete Account', style: AppStyles.headline3),
          content: Text(
            'Are you sure you want to permanently delete your account? This action cannot be undone.',
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
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Delete', style: AppStyles.bodyText1.copyWith(color: Colors.white)),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop();
                await _deleteAccount();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user logged in')),
        );
      }
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting account...')),
      );

      await _firestore.runTransaction((transaction) async {
        final userDoc = _firestore.collection('users').doc(user.uid);
        final docSnapshot = await transaction.get(userDoc);
        if (docSnapshot.exists) {
          transaction.delete(userDoc);
        }
      });

      await user.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.surfaceColor,
                    backgroundImage: _profileImageUrl != 'https://via.placeholder.com/150'
                        ? NetworkImage(_profileImageUrl)
                        : null,
                    child: _profileImageUrl == 'https://via.placeholder.com/150'
                        ? Icon(Icons.person, size: 50, color: AppColors.primaryColor)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(_userName, style: AppStyles.headline2.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(_userEmail, style: AppStyles.bodyText2.copyWith(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          _buildDrawerItem(Icons.home, 'Home', 0, () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const UserHomeScreen()));
          }),
          _buildDrawerItem(Icons.settings, 'Settings', 1, () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
              userName: _userName,
              userEmail: _userEmail,
              profileImageUrl: _profileImageUrl,
              onNameChanged: (newName) => setState(() => _userName = newName),
              onImageChanged: (newImageUrl) => setState(() => _profileImageUrl = newImageUrl),
              onEmailChanged: (newEmail) => setState(() => _userEmail = newEmail),
            )));
          }),
          const Divider(),
          _buildDrawerItem(Icons.logout, 'Logout', 2, () async {
            await _authService.signOut();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()), (route) => false);
          }, color: AppColors.errorColor),
          _buildDrawerItem(Icons.delete, 'Delete Account', 3, () {
            _showDeleteConfirmationDialog();
          }, color: AppColors.errorColor),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index, VoidCallback onTap, {Color? color}) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.blueAccent.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, color: color ?? (isSelected ? Colors.blue : AppColors.textPrimary)),
          title: Text(
            title,
            style: AppStyles.bodyText1.copyWith(color: color ?? (isSelected ? Colors.blue : AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}
