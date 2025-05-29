import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../widgets/rider_drawer.dart';
import 'ride_requests.dart';
import '../../services/auth_service.dart';
import '../auth/role_selection_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  final String riderId; // Add riderId parameter
  const RiderHomeScreen({super.key, required this.riderId});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();

  late final List<Widget> _screens; // Make _screens late-initialized

  @override
  void initState() {
    super.initState();
    // Initialize _screens with riderId
    _screens = [
      RideRequestsScreen(), // Pass riderId to RideRequestsScreen
    ];
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
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.secondaryColor,
                AppColors.secondaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        title: const Text(
          'RideApp Rider',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: const RiderDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.secondaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: _screens[0], // Directly use the first screen since there's only one
      ),
    );
  }
}