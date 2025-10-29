import 'dart:convert';
import 'dart:io';
import 'package:flock/TermsAndConditionsPage.dart';
import 'package:flock/location.dart';
import 'package:flock/privacy.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'otp_verification_screen.dart';
import 'constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isChecked = false;
  bool _obscureText = true;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _firstNameError;
  String? _lastNameError;
  String? _dobError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _termsError;

  final String _signupUrl = 'https://api.getflock.io/api/vendor/signup';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool isValidEmail(String email) {
    final RegExp regex = RegExp(r"^[\w.\+\-]+@([\w\-]+\.)+[\w\-]{2,4}$");
    return regex.hasMatch(email);
  }

  bool isValidPhone(String phone) {
    return RegExp(r'^\+?[0-9]{10,10}$').hasMatch(_phoneController.text);
  }

  bool _validateInputs() {
    bool isValid = true;
    setState(() {
      _firstNameError = null;
      _lastNameError = null;
      _dobError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _termsError = null;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();
    if (firstName.isEmpty) {
      _firstNameError = 'First name is required.';
      isValid = false;
    }
    if (lastName.isEmpty) {
      _lastNameError = 'Last name is required.';
      isValid = false;
    }
    if (email.isEmpty) {
      _emailError = 'Email is required.';
      isValid = false;
    } else if (!isValidEmail(email)) {
      _emailError = 'Please enter a valid email address.';
      isValid = false;
    }

    if (phone.isNotEmpty) {
      if (!isValidPhone(phone)) {
        _phoneError = 'Please enter a valid phone number.';
        isValid = false;
      }
    }
    // Use the new password validation
    _passwordError = AppConstants.validatePassword(password);
    if (_passwordError != null) {
      isValid = false;
    }

    if (!isChecked) {
      _termsError = 'Please accept Terms&Conditions and Privacy Policy.';
      isValid = false;
    }
    return isValid;
  }

  Future<void> _register() async {
    if (!_validateInputs()) return;

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String dob = _dobController.text.trim();
    final String location = _locationController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();
    final String password = _passwordController.text;

    try {
      final Map<String, dynamic> body = {
        'first_name': firstName,
        'last_name': lastName,
        'dob': dob.isEmpty ? null : dob,
        'location': location.isEmpty ? null : location,
        'email': email,
        'phone': phone.isEmpty ? null : phone,
        'password': password,
      };

      final response = await http.post(
        Uri.parse(_signupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint("Signup Response Status: ${response.statusCode}");
      debugPrint("Signup Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          debugPrint("Signup successful, navigating to OTP verification");

          await showDialog(
            context: context,
            builder:
                (_) => AlertDialog(
                  title: const Text('Success'),
                  content: const Text('OTP sent successfully.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        debugPrint("Dialog OK button pressed");
                        Navigator.of(context).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );

          // Navigate to OTP verification with replacement to clear stack
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => OtpVerificationScreen(
                      email: email,
                      firstName: firstName,
                      lastName: lastName,
                    ),
              ),
            );
          }
        } else {
          _showError(responseData['message'] ?? 'Registration failed.');
        }
      } else {
        _showError(
          'Registration failed. Please try again later or contact support if issue persists.',
        );
      }
    } catch (error) {
      debugPrint("Error during signup: $error");
      _showError('An error occurred. Please try again.');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _locationController.text =
                '${place.street}, ${place.locality}, ${place.country}';
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 25),
          content: Text('Unable to get location. Please try again.'),
        ),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? errorText,
    bool obscureText = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? Theme.of(context).colorScheme.surface.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  errorText != null
                      ? Colors.red
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14.0,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14.0,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 15,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              suffixIcon: suffixIcon,
            ),
            onChanged: onChanged,
          ),
        ),
        if (errorText != null)
          Align(
            alignment: AlignmentGeometry.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffold = Scaffold(
      // backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // appBar: AppBar(
      //   backgroundColor: const Color.fromRGBO(80, 76, 76, 1),
      //   elevation: 0,
      //   toolbarHeight: MediaQuery.of(context).size.height * 0.08,
      //   leading: IconButton(
      //     icon: Image.asset(
      //       'assets/back_updated.png',
      //       height: 40,
      //       width: 34,
      //     ), // Increased icon size
      //     onPressed: () => Navigator.of(context).pop(),
      //   ),
      //   leadingWidth: 80,
      // ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Positioned(
          //   left: 0,
          //   top: 0,
          //   child: IconButton(
          //     color: Theme.of(context).colorScheme.onSurface,
          //     icon: Image.asset(
          //       'assets/back_updated.png',
          //       height: 40,
          //       width: 34,
          //     ), // Increased icon size
          //     onPressed: () => Navigator.of(context).pop(),
          //   ),
          // ),
          Positioned.fill(
            child: Image.asset(
              isDarkMode ? 'assets/Background.jpg' : 'assets/login_back.jpg',
              fit: BoxFit.cover,
              color: Theme.of(
                context,
              ).colorScheme.surface.withOpacity(isDarkMode ? 0.1 : 0.2),
              colorBlendMode: BlendMode.darken,
            ),
          ),

          //    Positioned(
          //   top: MediaQuery.of(context).padding.top,
          //   left: 10,
          //   child: IconButton(
          //     icon: Image.asset('assets/back_updated.png', height: 48, width: 48),
          //      onPressed: () => Navigator.of(context).pop(),
          //   ),
          // ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentGeometry.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Image.asset(
                        'assets/back_updated.png',
                        height: 34,
                        width: 34,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/business_logo.png',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Create your account',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _firstNameController,
                          hintText: 'First Name',
                          errorText: _firstNameError,
                          onChanged: (value) {
                            if (_firstNameError != null) {
                              setState(() {
                                _firstNameError = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _lastNameController,
                          hintText: 'Last Name',
                          errorText: _lastNameError,
                          onChanged: (value) {
                            if (_lastNameError != null) {
                              setState(() {
                                _lastNameError = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Enter Email Address',
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      if (_emailError != null) {
                        setState(() {
                          _emailError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(
                    controller: _phoneController,
                    hintText: 'Enter phone number (optional)',
                    errorText: _phoneError,
                    keyboardType: TextInputType.phone,
                    onChanged: (value) {
                      if (_phoneError != null) {
                        setState(() {
                          _phoneError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(
                    controller: _dobController,
                    hintText: 'Date of Birth (optional)',
                    errorText: _dobError,
                    readOnly: true,
                    onTap: () async {
                      final DateTime today = DateTime.now();
                      final DateTime eighteenYearsAgo = DateTime(
                        today.year - 18,
                        today.month,
                        today.day,
                      );

                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: eighteenYearsAgo,
                      );

                      if (pickedDate != null) {
                        String formattedDate =
                            "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                        _dobController.text = formattedDate;
                      }
                    },
                    onChanged: (value) {
                      if (_dobError != null) {
                        setState(() {
                          _dobError = null;
                        });
                      }
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.calendar_today,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () async {
                        final DateTime today = DateTime.now();
                        final DateTime eighteenYearsAgo = DateTime(
                          today.year - 18,
                          today.month,
                          today.day,
                        );

                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: eighteenYearsAgo,
                        );

                        if (pickedDate != null) {
                          String formattedDate =
                              "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                          _dobController.text = formattedDate;
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildTextField(
                    controller: _locationController,
                    hintText: 'Enter your location (optional)',
                    onTap: () async {
                      final selectedLocation = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationPicker(),
                        ),
                      );
                      if (selectedLocation != null) {
                        setState(() {
                          _locationController.text =
                              selectedLocation['address'] ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 25),

                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Enter password',
                    errorText: _passwordError,
                    obscureText: _obscureText,
                    onChanged: (value) {
                      if (_passwordError != null) {
                        setState(() {
                          _passwordError = null;
                        });
                      }
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentGeometry.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Password must meet the following criteria:',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '- At least 8 characters long',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '- Contains at least one uppercase letter',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '- Contains at least one lowercase letter',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '- Contains at least one number',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '- Contains at least one special character',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: isChecked,
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              side: BorderSide(
                                color:
                                    _termsError != null
                                        ? Colors.red
                                        : Theme.of(context).colorScheme.outline,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (bool? value) {
                                setState(() {
                                  isChecked = value!;
                                  _termsError = null;
                                });
                              },
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Terms&Conditions ',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap = () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const TermsAndConditionsPage(),
                                                ),
                                              );
                                            },
                                    ),
                                    TextSpan(
                                      text: 'and ',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap = () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const PrivacyPage(),
                                                ),
                                              );
                                            },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_termsError != null)
                          Align(
                            alignment: AlignmentGeometry.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, left: 14),
                              child: Text(
                                _termsError!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  AppConstants.fullWidthButton(
                    text: "Continue",
                    onPressed: _register,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return Platform.isAndroid
        ? SafeArea(top: false, child: scaffold)
        : scaffold;
  }
}
