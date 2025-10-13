import 'dart:convert';
import 'package:flock/constants.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Design {
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool currentPasswordisEmpty = false;
  bool newPasswordisEmpty = false;
  bool confirmPasswordisEmpty = false;
  bool newAndConfirmPasswordMismatch = false;
  bool newAndCurrentPasswordMatched = false;

  String? passwordError;

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _changePassword() async {
    final String currentPassword = _currentPasswordController.text.trim();
    final String newPassword = _newPasswordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();
    if (currentPassword.isEmpty &&
        newPassword.isEmpty &&
        confirmPassword.isEmpty) {
      setState(() {
        currentPasswordisEmpty = true;
        newPasswordisEmpty = true;
        confirmPasswordisEmpty = true;
      });
      return;
    } else if (currentPassword.isEmpty) {
      setState(() {
        currentPasswordisEmpty = true;
      });
      return;
    } else if (newPassword.isEmpty) {
      setState(() {
        newPasswordisEmpty = true;
      });
      return;
    } else if (confirmPassword.isEmpty) {
      setState(() {
        confirmPasswordisEmpty = true;
      });
      return;
    } else if (currentPassword == newPassword) {
      setState(() {
        newAndCurrentPasswordMatched = true;
      });
      return;
    } else if (confirmPassword != newPassword) {
      setState(() {
        newAndConfirmPasswordMismatch = true;
      });
      return;
    } else {
      setState(() {
        currentPasswordisEmpty = false;
        newPasswordisEmpty = false;
        confirmPasswordisEmpty = false;
        newAndConfirmPasswordMismatch = false;
        newAndCurrentPasswordMatched = false;
      });
    }

    // Validate new password
    setState(() {
      passwordError = AppConstants.validatePassword(newPassword);
    });
    if (passwordError != null) return;
    // if (passwordError != null) {
    //   Fluttertoast.showToast(
    //     msg: passwordError,
    //     backgroundColor: Colors.red,
    //     textColor: Theme.of(context).colorScheme.onError,
    //   );
    //   return;
    // }

    // if (newPassword != confirmPassword) {
    //   Fluttertoast.showToast(
    //     msg: "New password and confirm password do not match",
    //     backgroundColor: Colors.red,
    //     textColor: Theme.of(context).colorScheme.onError,
    //   );
    //   return;
    // }

    final String urlString =
        "https://api.getflock.io/api/vendor/profile/change-password";
    final payload = {
      "old_password": currentPassword,
      "password": newPassword,
      "password_confirmation": confirmPassword,
    };

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      Fluttertoast.showToast(
        msg: "No token found. Please login again.",
        backgroundColor: Colors.red,
        textColor: Theme.of(context).colorScheme.onError,
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(urlString),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] != null &&
            data['message'].toString().toLowerCase().contains("success")) {
          Fluttertoast.showToast(
            msg: "Password changed successfully",
            backgroundColor: Colors.green,
            textColor: Theme.of(context).colorScheme.onPrimary,
          );
          Navigator.pop(context);
        } else {
          Fluttertoast.showToast(
            msg: data['message'] ?? "Failed to change password",
            backgroundColor: Colors.red,
            textColor: Theme.of(context).colorScheme.onError,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "Error: ${response.statusCode}",
          backgroundColor: Colors.red,
          textColor: Theme.of(context).colorScheme.onError,
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: "An error occurred. Please try again.",
        backgroundColor: Colors.red,
        textColor: Theme.of(context).colorScheme.onError,
      );
      debugPrint("Error during change password: $error");
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _getInputDecoration(
    String label,
    bool obscureText,
    VoidCallback toggleObscure,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[400]
                : Theme.of(context).textTheme.bodyMedium!.color,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBorder
                  : Theme.of(context).colorScheme.primary,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBorder
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2.0,
        ),
      ),
      filled: Theme.of(context).brightness == Brightness.dark,
      fillColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design.darkSurface
              : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      isDense: true,
      suffixIcon: IconButton(
        icon: Icon(
          obscureText ? Icons.visibility : Icons.visibility_off,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Theme.of(context).iconTheme.color,
        ),
        onPressed: toggleObscure,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design.darkBackground
              : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/back_updated.png',
                      height: 40,
                      width: 34,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Change Password",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.titleLarge!.color,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _currentPasswordController,
                obscureText: !_currentPasswordVisible,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                decoration: _getInputDecoration(
                  'Current Password',
                  !_currentPasswordVisible,
                  () => setState(() {
                    _currentPasswordVisible = !_currentPasswordVisible;
                  }),
                ),
                onChanged: (value) {
                  setState(() {
                    currentPasswordisEmpty = false;
                  });
                },
              ),

              if (currentPasswordisEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Current Password is required.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPasswordController,
                obscureText: !_newPasswordVisible,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                onChanged: (value) {
                  setState(() {
                    // Validate password as user types
                    newPasswordisEmpty = false;
                    newAndCurrentPasswordMatched = false;
                    // final error = AppConstants.validatePassword(value);
                    // if (error != null) {
                    //   ScaffoldMessenger.of(context).showSnackBar(
                    //     SnackBar(
                    //       content: Text(error),
                    //       backgroundColor: Colors.red,
                    //       duration: const Duration(seconds: 2),
                    //     ),
                    //   );
                    // }
                  });
                },
                decoration: _getInputDecoration(
                  'New Password',
                  !_newPasswordVisible,
                  () => setState(() {
                    _newPasswordVisible = !_newPasswordVisible;
                  }),
                ),
              ),
              if (newPasswordisEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "New Password is required.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              newAndCurrentPasswordMatched
                  ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Current and New Password cannot be same.",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  )
                  : Container(),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmPasswordController,
                obscureText: !_confirmPasswordVisible,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
                decoration: _getInputDecoration(
                  'Confirm Password',
                  !_confirmPasswordVisible,
                  () => setState(() {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  }),
                ),
                onChanged: (value) {
                  setState(() {
                    confirmPasswordisEmpty = false;
                    newAndConfirmPasswordMismatch = false;
                  });
                },
              ),
              if (confirmPasswordisEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Confirm Password is required.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              if (passwordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    passwordError!,
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              if (newAndConfirmPasswordMismatch)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "New Password and Confirm Password should be same.",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 15),
              Text(
                AppConstants.getPasswordRequirements(),
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    "Update Password",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
