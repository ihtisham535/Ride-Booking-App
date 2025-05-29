import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../widgets/user_drawer.dart';
import 'ride_booking.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  String? _userId; // Store the userId

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _loadUserId(); // Load userId when the screen initializes
  }

  Future<void> _loadUserId() async {
    try {
      final userId = await _authService.getCurrentUserId(); // Assuming this method exists
      if (userId != null) {
        setState(() {
          _userId = userId;
          _screens.addAll([
            const RideBookingScreen(),
          ]);
        });
      } else {
        print('DEBUG: No user is authenticated');
        _logout(); // Redirect to login if no user is authenticated
      }
    } catch (e) {
      print('DEBUG: Error loading userId: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $e')),
      );
    }
  }

  Future<void> _logout() async {
    print('Logout button pressed');
    try {
      print('Attempting to sign out...');
      await _authService.signOut();
      print('Sign out successful');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Logout error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(),
        ),
        title: const SizedBox.shrink(),
        centerTitle: true,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.primaryColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.primaryColor),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const UserDrawer(),
      body: _userId == null
          ? const Center(child: CircularProgressIndicator())
          : _screens.isNotEmpty
          ? _screens[0] // Directly use the first screen since there's only one
          : const Center(child: Text('Error loading screens')),
    );
  }
}