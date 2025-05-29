import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/extensions.dart';
import '../../utils/colors.dart';
import '../../utils/styles.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _locationController = TextEditingController(text: 'Multan, Punjab, Pakistan');
  final String _nationality = 'Pakistani';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  double? _latitude = 30.1575;
  double? _longitude = 71.5249;

  final String accessToken = 'YOUR_MAPBOX_ACCESS_TOKEN';

  @override
  void initState() {
    super.initState();
    _geocodeAddress(_locationController.text);
  }

  Future<void> _geocodeAddress(String address) async {
    try {
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$address.json?access_token=$accessToken&limit=1';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        if (features.isNotEmpty) {
          final coordinates = features[0]['geometry']['coordinates'] as List;
          setState(() {
            _latitude = coordinates[1];
            _longitude = coordinates[0];
          });
        }
      }
    } catch (e) {
      // Show error if needed
    }
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user == null) {
          throw Exception('User creation failed');
        }

        // Save user data in 'users' collection
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': widget.role,
        });

        // Save rider-specific data if role is rider
        if (widget.role == 'rider') {
          await FirebaseFirestore.instance.collection('rider').doc(user.uid).set({
            'riderId': user.uid,
            'email': user.email ?? _emailController.text.trim(),
            'name': _nameController.text.trim(),
            'vehicle': _vehicleTypeController.text.trim(),
            'plate': _licensePlateController.text.trim(),
            'rating': 0.0,
            'latitude': _latitude,
            'longitude': _longitude,
            'nationality': _nationality,
          });
        }

        if (!mounted) return;
        setState(() => _isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen(role: widget.role)),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account created successfully! Please login.'), backgroundColor: Colors.green),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {Widget? suffixIcon}) {
    final themeColor = widget.role == 'user' ? Colors.blue : Colors.teal;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: themeColor),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: themeColor.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor, width: 2), borderRadius: BorderRadius.circular(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.role == 'user' ? Colors.blue : Colors.teal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${widget.role.capitalize()} Sign Up', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: themeColor)),
              const SizedBox(height: 8),
              Text('Create your account to get started', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red[900])),
                ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(controller: _nameController, decoration: _buildInputDecoration('Full Name', Icons.person), validator: (v) => v!.isEmpty ? 'Enter name' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _emailController, decoration: _buildInputDecoration('Email', Icons.email), validator: (v) => v!.contains('@') ? null : 'Enter valid email'),
                    const SizedBox(height: 12),
                    TextFormField(controller: _phoneController, decoration: _buildInputDecoration('Phone', Icons.phone), validator: (v) => v!.isEmpty ? 'Enter phone' : null),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: _buildInputDecoration('Password', Icons.lock, suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      )),
                      validator: (v) => v!.length >= 6 ? null : 'Password too short',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: _buildInputDecoration('Confirm Password', Icons.lock, suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      )),
                      validator: (v) => v == _passwordController.text ? null : 'Passwords do not match',
                    ),
                    if (widget.role == 'rider') ...[
                      const SizedBox(height: 12),
                      TextFormField(controller: _vehicleTypeController, decoration: _buildInputDecoration('Vehicle Type', Icons.directions_car), validator: (v) => v!.isEmpty ? 'Enter vehicle type' : null),
                      const SizedBox(height: 12),
                      TextFormField(controller: _licensePlateController, decoration: _buildInputDecoration('License Plate', Icons.confirmation_number), validator: (v) => v!.isEmpty ? 'Enter license plate' : null),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextFormField(controller: _locationController, decoration: _buildInputDecoration('Location', Icons.location_on))),
                          IconButton(icon: Icon(Icons.search, color: themeColor), onPressed: () => _geocodeAddress(_locationController.text)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_latitude != null && _longitude != null) Text('Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}'),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(minimumSize: Size(mediaQuery.size.width * 0.8, 50), backgroundColor: themeColor),
                      child: _isLoading ? CircularProgressIndicator(color: Colors.white) : Text('Create Account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen(role: widget.role))),
                      child: Text('Already have an account? Login', style: TextStyle(color: themeColor)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleTypeController.dispose();
    _licensePlateController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}
