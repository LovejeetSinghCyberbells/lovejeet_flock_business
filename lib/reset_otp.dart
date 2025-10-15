import 'dart:convert';
import 'dart:io';
import 'package:flock/NewPasswordScreen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class Design {
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);
  static const Color primaryColorOrange = Color.fromRGBO(255, 152, 0, 1);
}

class OtpVerificationScreen1 extends StatefulWidget {
  final String email;
  const OtpVerificationScreen1({required this.email, super.key});

  @override
  _OtpVerificationScreen1State createState() => _OtpVerificationScreen1State();
}

class _OtpVerificationScreen1State extends State<OtpVerificationScreen1> {
  final TextEditingController _otpController = TextEditingController();
  final String _otpUrl = 'https://api.getflock.io/api/vendor/otp-login';
  bool otpError = false;

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

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final String otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() {
        otpError = true;
      });
      return;
    }

    try {
      final Map<String, dynamic> body = {'email': widget.email, 'otp': otp};

      final response = await http.post(
        Uri.parse(_otpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NewPasswordScreen(email: widget.email),
            ),
          );
        } else {
          // Show error if status isn't success
          Fluttertoast.showToast(
            msg: responseData['message'] ?? 'OTP verification failed.',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: 'OTP verification failed.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (error) {
      Fluttertoast.showToast(
        msg: 'An error occurred. Please try again.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
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
        title: Text(
          'OTP Verification',
          style: TextStyle(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Enter the OTP sent to your email',
              style: TextStyle(
                fontSize: 16,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
              ),
              decoration: _getInputDecoration('OTP'),
              onChanged: (value) {
                setState(() {
                  otpError = false;
                });
              },
            ),
            if (otpError)
              Align(
                alignment: AlignmentGeometry.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please enter the otp.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Design.primaryColorOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                onPressed: _verifyOtp,
                child: const Text(
                  'Verify OTP',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Platform.isAndroid
        ? SafeArea(top: false, child: scaffold)
        : scaffold;
  }
}
