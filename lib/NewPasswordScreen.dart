import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flock/constants.dart'; // Assuming this is where AppConstants is defined
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NewPasswordScreen extends StatefulWidget {
  final String email;
  const NewPasswordScreen({required this.email, super.key});

  @override
  _NewPasswordScreenState createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _resetPassword() async {
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.getflock.io/api/vendor/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'password': password}),
      );

      if (response.statusCode == 200) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('An error occurred')));
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Set New Password'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppConstants.customPasswordField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              toggleObscure: _togglePasswordVisibility,
              hintText: 'New Password',
            ),
            const SizedBox(height: 20),
            AppConstants.customPasswordField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              toggleObscure: _toggleConfirmPasswordVisibility,
              hintText: 'Confirm New Password',
            ),
            const SizedBox(height: 40),
            AppConstants.fullWidthButton(
              text: 'Reset Password',
              onPressed: _resetPassword,
            ),
          ],
        ),
      ),
    );
    return Platform.isAndroid ? SafeArea(child: scaffold) : scaffold;
  }
}
