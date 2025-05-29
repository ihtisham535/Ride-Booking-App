import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../user/user_home.dart';
import '../rider/rider_home.dart';
import '../auth/signup_screen.dart';
import '../auth/forgot_password_screen.dart';
import '../../utils/extensions.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isCheckingAuth = true;
  bool _obscurePassword = true;
  bool _userInitiatedLogin = false;

  @override
  void initState() {
    super.initState();
    _checkAndResetAuth();
    _setupAuthStateListener();
  }

  void _checkAndResetAuth() async {
    if (_authService.currentUser != null) {
      await _authService.signOut();
    }
    setState(() => _isCheckingAuth = false);
  }

  void _setupAuthStateListener() {
    _authService.authStateChanges.listen((User? user) {
      if (mounted) {
        setState(() => _isCheckingAuth = false);
        if (user != null && _userInitiatedLogin) _navigateToHome(user.uid);
      }
    });
  }

  void _navigateToHome(String userId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.role == 'user'
            ? const UserHomeScreen()
            : RiderHomeScreen(riderId: userId),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _userInitiatedLogin = true;
      });

      try {
        // Trimmed email and password for safety
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // Firebase Auth sign in
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

        // Success handling will be in authStateChanges listener
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
          _userInitiatedLogin = false;
        });

        String errorMsg = 'Login failed. Please try again.';
        if (e.code == 'user-not-found') {
          errorMsg = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          errorMsg = 'Incorrect password.';
        } else if (e.code == 'invalid-email') {
          errorMsg = 'Invalid email format.';
        } else if (e.code == 'user-disabled') {
          errorMsg = 'This user account has been disabled.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SignupScreen(role: widget.role)),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForgotPasswordScreen(role: widget.role)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = widget.role == 'user' ? Colors.blue : Colors.green;
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isCheckingAuth) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [primaryColor.withOpacity(0.05), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 🔥 Updated Responsive Header
                  _buildHeader(theme, isDarkMode, screenWidth),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_rounded,
                            primaryColor: primaryColor,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_rounded,
                            primaryColor: primaryColor,
                            isDarkMode: isDarkMode,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: primaryColor,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _navigateToForgotPassword,
                              child: Text('Forgot Password?', style: TextStyle(color: primaryColor)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                                : const Text('Login', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Don\'t have an account?', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[700])),
                              TextButton(
                                onPressed: _navigateToSignup,
                                child: Text('Sign Up', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode, double screenWidth) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(screenWidth * 0.06),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.blue[800] : Colors.blue[700],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.emoji_transportation,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Routo',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: isDarkMode ? Colors.white : Colors.blue[900],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your journey, your choice',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    required bool isDarkMode,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: isDarkMode ? Colors.white : Colors.grey[800]),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2), borderRadius: BorderRadius.circular(14)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your $label';
        if (label == 'Email' && !value.contains('@')) return 'Please enter a valid email';
        if (label == 'Password' && value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }
}
