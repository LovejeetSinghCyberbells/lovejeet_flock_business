import 'dart:async'; // Import for TimeoutException
import 'dart:convert';
import 'dart:io';
import 'package:flock/constants.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'reset_otp.dart'; // replace with actual path

class Design {
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);
  static const Color primaryColorOrange = Color.fromRGBO(255, 152, 0, 1);
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? emailError;

  // Theme-aware input decoration
  InputDecoration _getInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,

      hintStyle: TextStyle(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[400]
                : Colors.grey[600],
        fontSize: 14.0,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      filled: true,
      fillColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design.darkSurface
              : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBorder
                  : Colors.grey.withOpacity(0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBorder
                  : Colors.grey.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Design.primaryColorOrange),
      ),
    );
  }

  Future<void> _resetPassword() async {
    final String email = _emailController.text.trim();
    bool isValidEmail(String email) {
      final RegExp regex = RegExp(r"^[\w.\+\-]+@([\w\-]+\.)+[\w\-]{2,4}$");
      return regex.hasMatch(email);
    }

    if (email.isEmpty) {
      setState(() {
        emailError = "Email is required.";
      });
      // Fluttertoast.showToast(
      //   msg: "Please enter your email address.",
      //   backgroundColor: Colors.red,
      //   textColor: Colors.white,
      // );
      return;
    } else if (!isValidEmail(email)) {
      setState(() {
        emailError = 'Please enter a valid email address.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        "https://api.getflock.io/api/vendor/forgot-password",
      );
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(
            const Duration(seconds: 10),
          ); // Add a timeout for the request

      setState(() {
        _isLoading = false;
      });

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (responseData['message'] != null &&
            responseData['message'].toString().toLowerCase().contains(
              'success',
            )) {
          Fluttertoast.showToast(
            msg: "OTP sent successfully.",
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen1(email: email),
            ),
          );
        } else {
          Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Reset failed.',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else if (response.statusCode == 422) {
        // Handle 422 Unprocessable Entity
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          final errorMessage = errors.entries
              .map((e) => '${e.key}: ${e.value.join(', ')}')
              .join('\n');
          Fluttertoast.showToast(
            msg: errorMessage,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        } else {
          Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Validation failed.',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        // Handle other status codes
        debugPrint("Error response: ${response.body}");
        Fluttertoast.showToast(
          msg: "Please enter a registered email.",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } on TimeoutException catch (e) {
      // Handle timeout errors
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Request timed out. Please try again.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      debugPrint("Timeout error: $e");
    } on http.ClientException catch (e) {
      // Handle network-related errors (e.g., no internet connection)
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "Network error. Please check your internet connection.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      debugPrint("Network error: $e");
    } catch (error) {
      // Handle all other errors
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: "An error occurred. Please try again.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      debugPrint("Unexpected error: $error");
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design.darkBackground
              : Colors.white,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Design.darkBackground
                : Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10.0),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
              size: 20,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/Background.jpg'
                      : 'assets/login_back.jpg',
                ),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/business_logo.png',
                    height: 120,
                    width: 120,
                  ),
                  const SizedBox(height: 40),
                  // Title
                  Text(
                    "Reset Password",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Input field with shadow
                  Container(
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Design.darkSurface
                              : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5.0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _emailController,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                      ),
                      decoration: _getInputDecoration("Enter Email Address"),
                      onChanged: (value) {
                        setState(() {
                          emailError = null;
                        });
                      },
                    ),
                  ),
                  if (emailError != null)
                    Align(
                      alignment: AlignmentGeometry.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          emailError!,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  AppConstants.fullWidthButton(
                    text: "Continue",
                    onPressed: _resetPassword,
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Stack(
              children: [
                // Semi-transparent dark overlay
                Container(color: Colors.black.withOpacity(0.14)),
                // Loader container
                Container(
                  color: Colors.white10,
                  child: Center(
                    child: Image.asset(
                      'assets/Bird_Full_Eye_Blinking.gif',
                      width: 100,
                      height: 100,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
    return Platform.isAndroid ? SafeArea(child: scaffold) : scaffold;
  }
}
