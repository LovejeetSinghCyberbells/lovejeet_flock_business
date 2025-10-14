import 'dart:convert';
import 'package:flock/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:async';
import 'package:flock/services/fcm_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// For inline validation errors:
  String? _emailError;
  String? _passwordError;

  final String _loginUrl = 'https://api.getflock.io/api/vendor/login';
  final String _deviceUpdateUrl =
      'https://api.getflock.io/api/vendor/devices/update';
  final String _appLogsUrl =
      'https://api.getflock.io/api/customer/app-logs/store';

  // Add logging levels
  static const String _logPrefix = '[Flock Business]';

  void _logInfo(String message) {
    _logWithLevel('INFO', message);
  }

  void _logError(String message) {
    _logWithLevel('ERROR', message);
  }

  void _logDebug(String message) {
    _logWithLevel('DEBUG', message);
  }

  void _logWarning(String message) {
    _logWithLevel('WARNING', message);
  }

  void _logWithLevel(String level, String message) {
    final String formattedMessage = '$_logPrefix [$level] $message';

    // Always log in both debug and release mode
    developer.log(
      formattedMessage,
      time: DateTime.now(),
      level: 1000,
      name: 'FlockBusiness',
      error: message,
    );

    // Also use debugPrint for immediate console visibility
    foundation.debugPrint(formattedMessage);
  }

  void _refreshData() {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  bool isValidEmail(String email) {
    final RegExp regex = RegExp(r"^[\w.\+\-]+@([\w\-]+\.)+[\w\-]{2,4}$");
    return regex.hasMatch(email);
  }

  bool _validateInputs() {
    bool isValid = true;
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _emailError = 'Email is required.';
      isValid = false;
    } else if (!isValidEmail(email)) {
      _emailError = 'Please enter a valid email address.';
      isValid = false;
    }

    if (password.isEmpty) {
      _passwordError = 'Password is required.';
      isValid = false;
    }

    return isValid;
  }

  Future<void> _storeAppLog(
    String accessToken,
    String activity, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      String buildMode = 'Debug';
      if (foundation.kReleaseMode) {
        buildMode = 'Release';
      } else if (foundation.kProfileMode) {
        buildMode = 'Profile';
      }

      final response = await http.post(
        Uri.parse(_appLogsUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'activity': activity,
          'payload': payload,
          'device_agent':
              'Flock Business App ${Platform.isIOS ? 'iOS' : 'Android'} $buildMode',
          'device_timestamp': DateTime.now().toIso8601String(),
        }),
      );
      _logInfo(
        'Stored log for activity: $activity, Status: ${response.statusCode}',
      );
    } catch (e) {
      _logError('Failed to store log for activity: $activity, Error: $e');
    }
  }

  Future<void> _updateDeviceToken(String accessToken) async {
    try {
      await _storeAppLog(
        accessToken,
        'device_token_update_started',
        payload: {
          'platform': Platform.isIOS ? 'iOS' : 'Android',
          'environment': foundation.kReleaseMode ? 'Production' : 'Debug',
          'timestamp_start': DateTime.now().toIso8601String(),
        },
      );

      _logInfo('====== Starting Device Token Update ======');
      _logDebug('Current Platform: ${Platform.isIOS ? 'iOS' : 'Android'}');
      _logDebug(
        'Environment: ${foundation.kReleaseMode ? 'Production' : 'Debug'}',
      );
      _logDebug('Access Token Valid: ${accessToken.isNotEmpty}');

      final uri = Uri.parse(_deviceUpdateUrl);
      _logDebug('Protocol: ${uri.scheme}');
      _logDebug('Host: ${uri.host}');
      _logDebug('Path: ${uri.path}');

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? fcmToken;

      if (Platform.isIOS) {
        _logInfo('Requesting iOS notification permissions...');
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        _logDebug('iOS notification settings:');
        _logDebug('- Authorization status: ${settings.authorizationStatus}');

        int maxRetries = foundation.kReleaseMode ? 10 : 5;
        int currentRetry = 0;
        String? apnsToken;

        while (currentRetry < maxRetries) {
          _logDebug(
            'Attempting to get APNS token (Attempt ${currentRetry + 1}/$maxRetries)',
          );
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) {
            _logInfo('APNS token obtained successfully');
            break;
          }
          _logWarning('APNS token not available, waiting longer...');
          await Future.delayed(
            Duration(seconds: foundation.kReleaseMode ? 3 : 2),
          );
          currentRetry++;
        }

        if (apnsToken == null) {
          _logError('Failed to get APNS token after $maxRetries attempts');
          await _storeAppLog(accessToken, 'device_token_update_started');
          return;
        }
      }

      int fcmMaxRetries = foundation.kReleaseMode ? 5 : 3;
      int fcmCurrentRetry = 0;

      while (fcmCurrentRetry < fcmMaxRetries) {
        _logDebug(
          'Attempting to get FCM token (Attempt ${fcmCurrentRetry + 1}/$fcmMaxRetries)',
        );
        try {
          fcmToken = await messaging.getToken();
          if (fcmToken != null) {
            _logInfo('FCM token obtained successfully');
            break;
          }
        } catch (e) {
          _logError('Error getting FCM token: $e');
        }
        await Future.delayed(
          Duration(seconds: foundation.kReleaseMode ? 3 : 2),
        );
        fcmCurrentRetry++;
      }

      if (fcmToken == null) {
        _logError('Failed to get FCM token after $fcmMaxRetries attempts');
        await _storeAppLog(accessToken, 'device_token_update_started');
        return;
      }

      if (fcmToken.length > 255) {
        _logError('FCM token exceeds maximum length of 255 characters');
        await _storeAppLog(accessToken, 'device_token_update_started');
        return;
      }

      final deviceType = Platform.isIOS ? 'ios' : 'android';
      final requestBody = {'token': fcmToken, 'type': deviceType};

      if (!accessToken.isNotEmpty) {
        _logError('Access token is empty, aborting API call');
        await _storeAppLog(accessToken, 'device_token_update_started');
        return;
      }

      _logInfo('====== Making API Call ======');
      _logDebug('Full URL: $_deviceUpdateUrl');

      await _storeAppLog(
        accessToken,
        'device_token_before_updating_device_token',
        payload: {
          'platform': Platform.isIOS ? 'iOS' : 'Android',
          'environment': foundation.kReleaseMode ? 'Production' : 'Debug',
          'timestamp_start': DateTime.now().toIso8601String(),
        },
      );

      try {
        final response = await http
            .post(
              Uri.parse(_deviceUpdateUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
                'Accept': 'application/json',
                'User-Agent':
                    'Flock Business App ${Platform.isIOS ? 'iOS' : 'Android'} ${foundation.kReleaseMode ? 'Production' : 'Debug'}',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(
              Duration(seconds: foundation.kReleaseMode ? 60 : 30),
              onTimeout: () {
                _storeAppLog(
                  accessToken,
                  'device_token_update_timeout',
                  payload: {
                    'platform': Platform.isIOS ? 'iOS' : 'Android',
                    'environment':
                        foundation.kReleaseMode ? 'Production' : 'Debug',
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );
                _logWarning('Request timed out');
                throw TimeoutException('Request timed out');
              },
            );

        await _storeAppLog(accessToken, '${response.statusCode}');

        _logInfo('====== Response Received ======');
        _logDebug('Status Code: ${response.statusCode}');
        _logDebug('Response Headers: ${response.headers}');
        _logDebug('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          await _storeAppLog(accessToken, '${response.statusCode}');

          _logInfo('Device token updated successfully');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'last_token_update',
            DateTime.now().toIso8601String(),
          );
          await FCMService.setupFCMListeners(accessToken);

          await _storeAppLog(
            accessToken,
            'device_token_update_success',
            payload: {
              'platform': Platform.isIOS ? 'iOS' : 'Android',
              'environment': foundation.kReleaseMode ? 'Production' : 'Debug',
              'timestamp_end': DateTime.now().toIso8601String(),
              'response_status': response.statusCode,
            },
          );
        } else {
          _logError(
            'Failed to update device token. Status: ${response.statusCode}',
          );

          await _storeAppLog(
            accessToken,
            'device_token_update_failed',
            payload: {
              'platform': Platform.isIOS ? 'iOS' : 'Android',
              'environment': foundation.kReleaseMode ? 'Production' : 'Debug',
              'timestamp_end': DateTime.now().toIso8601String(),
              'error_status': response.statusCode,
              'error_body': response.body,
            },
          );

          throw Exception(
            'Failed to update device token: ${response.statusCode}',
          );
        }
      } catch (e) {
        _logError('====== API Call Failed ======');
        _logError('Error Type: ${e.runtimeType}');
        _logError('Error Details: $e');

        await _storeAppLog(
          accessToken,
          'device_token_update_error',
          payload: {
            'platform': Platform.isIOS ? 'iOS' : 'Android',
            'environment': foundation.kReleaseMode ? 'Production' : 'Debug',
            'timestamp_error': DateTime.now().toIso8601String(),
            'error_type': e.runtimeType.toString(),
            'error_message': e.toString(),
          },
        );

        if (e is SocketException) {
          _logWarning('Network Error: Could not connect to server');
        } else if (e is TimeoutException) {
          _logWarning('Request timed out');
        } else if (e is HandshakeException) {
          _logWarning('SSL/Security Error');
        }
        rethrow;
      }
    } catch (error, stackTrace) {
      _logError('Error in _updateDeviceToken: $error');
      _logError('Stack trace: $stackTrace');

      await _storeAppLog(
        accessToken,
        'device_token_update_uncaught_error',
        payload: {
          'platform': Platform.isIOS ? 'iOS' : 'Android',
          'environment': foundation.kReleaseMode ? 'Production' : 'Debug',
          'timestamp_error': DateTime.now().toIso8601String(),
          'error_message': error.toString(),
          'stack_trace': stackTrace.toString(),
        },
      );
    }
  }

  Future<void> _login() async {
    if (!_validateInputs()) return;

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    try {
      final Map<String, dynamic> body = {'email': email, 'password': password};

      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['message'] != null &&
            responseData['message'].toString().toLowerCase().contains(
              'success',
            )) {
          final token = responseData['data']['access_token'];

          String? userId;
          String? userEmail;
          String? fName;
          String? lName;
          List<Map<String, dynamic>>? permissions;

          if (responseData['data'] != null &&
              responseData['data']['user'] != null) {
            userId = responseData['data']['user']['id']?.toString();
            userEmail = responseData['data']['user']['email']?.toString();
            fName = responseData['data']['user']['first_name']?.toString();
            lName = responseData['data']['user']['last_name']?.toString();
            permissions = List<Map<String, dynamic>>.from(
              responseData['data']['user']['permissions'] ?? [],
            );
            _logDebug('First name from API: $fName');
            _logDebug('Last name from API: $lName');
            _logDebug('User details: ${responseData['data']['user']}');
          } else {
            userId =
                responseData['userId']?.toString() ??
                responseData['vendor_id']?.toString();
          }

          SharedPreferences prefs = await SharedPreferences.getInstance();
          final permissionsJson = jsonEncode(permissions);
          await prefs.setString('permissions', permissionsJson);
          await prefs.setString('access_token', token);
          await prefs.setBool('isLoggedIn', true);

          if (userId != null) await prefs.setString('userid', userId);
          if (userEmail != null) await prefs.setString('email', userEmail);
          if (fName != null) await prefs.setString('firstName', fName);
          if (lName != null) await prefs.setString('lastName', lName);

          _logDebug('Stored firstName: ${prefs.getString('firstName')}');
          _logDebug('Stored lastName: ${prefs.getString('lastName')}');

          // Navigate first, then update token in background
          Navigator.pushReplacementNamed(context, '/home');
          _refreshData();

          // Add a longer delay before updating device token in release mode
          _logInfo('Waiting before device token update...');
          await Future.delayed(
            Duration(seconds: foundation.kReleaseMode ? 5 : 2),
          );

          // Call API to update device token after successful login
          try {
            await _updateDeviceToken(token);
          } catch (e) {
            _logError('Failed to update device token: $e');
            // Retry once after a longer delay
            await Future.delayed(Duration(seconds: 3));
            try {
              await _updateDeviceToken(token);
            } catch (e) {
              _logError('Failed to update device token on retry: $e');
            }
          }
        } else {
          _showError(
            responseData['message'] ?? 'Please check your email or password',
          );
        }
      } else {
        if (response.statusCode == 401) {
          _showError(
            'Invalid credentials. Please check your email or password.',
          );
        } else {
          final message = responseData['message'] ?? 'Login failed.';
          _showError(message);
        }
      }
    } catch (error) {
      _showError('An error occurred. Please try again.');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(
              'Login Failed',
              style: TextStyle(
                fontSize: 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            content: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildEmailField() {
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
                  _emailError != null
                      ? Colors.red
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
              ),
            ),
            child: TextFormField(
              controller: _emailController,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14.0,
                fontFamily: 'YourFontFamily',
              ),
              decoration: InputDecoration(
                hintText: "Enter Email Address",
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14.0,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              validator: (v) => null,
              onChanged: (value) {
                setState(() {
                  _emailError = null;
                });
              },
            ),
          ),
        ),
        if (_emailError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _emailError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
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
                  _passwordError != null
                      ? Colors.red
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
              ),
            ),
            child: TextFormField(
              controller: _passwordController,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14.0,
                fontFamily: 'YourFontFamily',
              ),
              decoration: InputDecoration(
                hintText: "Enter Password",
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 14.0,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              validator: (v) => null,
              onChanged: (value) {
                setState(() {
                  _passwordError = null;
                });
              },
            ),
          ),
        ),
        if (_passwordError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _passwordError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
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
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/business_logo.png',
                          width: 120,
                          height: 120,
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 24,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Login to your account',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildEmailField(),
                        const SizedBox(height: 15),
                        _buildPasswordField(),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                () => {
                                  _refreshData(),

                                  Navigator.pushNamed(
                                    context,
                                    '/forgot-password',
                                  ),
                                },
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(fontSize: 14),
                                children: [
                                  TextSpan(
                                    text: 'Forgot password? ',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Reset here',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        AppConstants.fullWidthButton(
                          text: 'Continue',
                          onPressed: _login,
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed:
                              () => {
                                _refreshData(),
                                Navigator.pushNamed(context, '/register'),
                              },
                          child: Text.rich(
                            TextSpan(
                              text: 'Don\'t have an account? ',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              children: [
                                TextSpan(
                                  text: 'Create New',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
