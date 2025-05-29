import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import '../../services/auth_service.dart';
import '../../screens/rider/rider_home.dart';
import 'rider_settings_screen.dart';
import '../../screens/auth/role_selection_screen.dart';  // ✅ Import RoleSelectionScreen

class RiderDrawer extends StatefulWidget {
  const RiderDrawer({super.key});

  @override
  State<RiderDrawer> createState() => _RiderDrawerState();
}

class _RiderDrawerState extends State<RiderDrawer> {
  final AuthService _authService = AuthService();
  String _userName = 'Rider User';
  String _userEmail = 'Loading...';
  String _profileImageUrl = 'https://via.placeholder.com/150';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
    _fetchInitialUser();
  }

  void _listenToAuthChanges() {
    _authSubscription = _authService.authStateChanges.listen((User? user) {
      if (user != null && mounted) {
        _fetchUserProfile(user.uid).then((_) {
          if (mounted) setState(() {});
        }).catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error fetching profile: $e')),
            );
          }
        });
      } else if (mounted) {
        setState(() {
          _userName = 'Rider User';
          _userEmail = 'No email available';
          _profileImageUrl = 'https://via.placeholder.com/150';
        });
      }
    });
  }

  Future<void> _fetchInitialUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? 'No email available';
      });
      await _fetchUserProfile(user.uid);
    }
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('rider').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'Rider User';
          _userEmail = _authService.currentUser?.email ?? doc.data()?['email'] ?? 'No email available';
          _profileImageUrl = doc.data()?['profileImageUrl'] ?? 'https://via.placeholder.com/150';
        });
      } else if (mounted) {
        await _createDefaultProfile(uid);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userEmail = _authService.currentUser?.email ?? 'No email available';
          _userName = _authService.currentUser?.displayName ?? 'Rider User';
          _profileImageUrl = 'https://via.placeholder.com/150';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching profile: $e')));
      }
    }
  }

  Future<void> _createDefaultProfile(String uid) async {
    try {
      final user = _authService.currentUser;
      if (user != null && mounted) {
        final email = user.email ?? 'default@example.com';
        final name = user.displayName ?? 'Rider User';
        await _firestore.collection('rider').doc(uid).set({
          'riderId': uid,
          'name': name,
          'email': email,
          'profileImageUrl': 'https://via.placeholder.com/150',
          'vehicle': 'Default Vehicle',
          'plate': 'ABC-123',
          'rating': 0,
          'latitude': 0.0,
          'longitude': 0.0,
          'nationality': 'Pakistani',
        }, SetOptions(merge: true));
        setState(() {
          _userName = name;
          _userEmail = email;
          _profileImageUrl = 'https://via.placeholder.com/150';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating profile: $e')));
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account', style: AppStyles.headline3),
          content: Text('Are you sure you want to delete your account? This action cannot be undone.', style: AppStyles.bodyText1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              child: Text('Cancel', style: AppStyles.bodyText1),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: AppStyles.bodyText1.copyWith(color: Colors.red)),
              onPressed: () async {
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
    if (user == null) return;
    try {
      await _firestore.collection('rider').doc(user.uid).delete();
      await user.delete();
      await _authService.signOut();  // ✅ Ensure full sign-out
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),  // ✅ Redirect to RoleSelectionScreen
              (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: AppColors.backgroundColor,
        child: ListView(
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
                      backgroundColor: Colors.white,
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
            _buildDrawerItem(Icons.home, 'Home', () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RiderHomeScreen(riderId: _authService.currentUser?.uid ?? '')));
            }),
            _buildDrawerItem(Icons.settings, 'Settings', () async {
              final user = _authService.currentUser;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => RiderSettingsScreen(
                  userName: _userName,
                  userEmail: _userEmail,
                  profileImageUrl: _profileImageUrl,
                  onNameChanged: (newName) => setState(() => _userName = newName),
                  onImageChanged: (newImageUrl) => setState(() => _profileImageUrl = newImageUrl),
                  onEmailChanged: (newEmail) => setState(() => _userEmail = newEmail),
                  riderId: user?.uid ?? '',
                ),
              ));
            }),
            const Divider(),
            _buildDrawerItem(Icons.logout, 'Logout', () async {
              await _authService.signOut();
              if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
            }, color: Colors.red),
            _buildDrawerItem(Icons.delete, 'Delete Account', _showDeleteConfirmationDialog, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.blueAccent.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: color ?? AppColors.accentColor),
          title: Text(title, style: AppStyles.bodyText1.copyWith(color: color ?? AppColors.textPrimary)),
        ),
      ),
    );
  }
}
