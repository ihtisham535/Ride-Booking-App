import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/user/user_home.dart';
import '../screens/rider/rider_home.dart';

class AuthWrapper extends StatelessWidget {
  final String role;
  const AuthWrapper({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          final user = snapshot.data!;
          if (role == 'user') {
            return const UserHomeScreen();
          } else if (role == 'rider') {
            return RiderHomeScreen(riderId: user.uid); // Pass riderId
          }
        }

        // User is not logged in
        return LoginScreen(role: role);
      },
    );
  }
}