import 'dart:convert';
import 'dart:io';
import 'package:flock/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  String _name = '';
  String _email = '';
  String? _phone;
  final TextEditingController _reasonController = TextEditingController();

  bool _isDeleting = false;
  String _errorMessage = '';

  bool nameError = false;
  bool emailError = false;
  bool reasonError = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails(); // Load user details when the screen initializes
  }

  /// Retrieve user details from SharedPreferences
  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      String firstName = prefs.getString('firstName') ?? '';
      String lastName = prefs.getString('lastName') ?? '';
      _name = ('$firstName $lastName').trim();
      _email = prefs.getString('email') ?? '';
      String phone = prefs.getString('phone') ?? '';
      _phone = phone.isNotEmpty ? phone : null;
    });
  }

  /// Retrieve token from SharedPreferences
  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Send POST request to delete account
  Future<void> _deleteAccount() async {
    final String name = _name.trim();
    final String email = _email.trim();
    final String? phone = _phone;
    final String reason = _reasonController.text.trim();
    // if (name.isEmpty || email.isEmpty || reason.isEmpty) {
    //   Fluttertoast.showToast(msg: 'Reason field is required');
    //   return;
    // }

    if (name.isEmpty) {
      setState(() {
        nameError = true;
      });
      return;
    } else if (email.isEmpty) {
      setState(() {
        emailError = true;
      });
      return;
    } else if (reason.isEmpty) {
      setState(() {
        reasonError = true;
      });
      return;
    } else {
      setState(() {
        nameError = false;
        emailError = false;
        reasonError = false;
      });
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = '';
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _isDeleting = false;
      });
      Fluttertoast.showToast(msg: 'No token found. Please login again.');
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/profile/delete');

    final body = {
      'name': name,
      'email': email,
      if (phone != null && phone.isNotEmpty)
        'phone': phone, // Include phone only if provided
      'reason': reason,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      setState(() {
        _isDeleting = false;
      });
      // if (mounted) {
      //   Navigator.pushAndRemoveUntil(
      //     context,
      //     MaterialPageRoute(builder: (_) => LoginScreen()),
      //     (Route<dynamic> route) => false,
      //   );
      // }
      // Fluttertoast.showToast(msg: 'Account deleted successfully.');

      print("Response : ${response.body} status code: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          Fluttertoast.showToast(msg: data['message'] ?? 'Account deleted.');
          if (mounted) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            await prefs.setBool('isLoggedIn', false);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          Fluttertoast.showToast(msg: data['message'] ?? 'Delete failed.');
        }
      } else {
        Fluttertoast.showToast(msg: 'Delete failed. ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });
      Fluttertoast.showToast(msg: 'An error occurred. Please try again.');
      debugPrint('Delete account error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                              "Delete Account",
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage.isNotEmpty)
                      Text(
                        _errorMessage,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.redAccent
                                  : Colors.red,
                        ),
                      ),

                    // Name (plain text)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text(
                            "Name: ",
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(
                              _name,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (nameError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Name field is required.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    // Email (plain text)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text(
                            "Email: ",
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: Text(
                              _email,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (emailError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Email field is required.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    // Phone (plain text, only if present)
                    if (_phone != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Text(
                              "Phone: ",
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                _phone!,
                                style: Theme.of(context).textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 15),

                    // Reason to delete (editable)
                    TextField(
                      controller: _reasonController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: "Enter the reason to delete the account",
                        hintStyle: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        border: Theme.of(context).inputDecorationTheme.border,
                        focusedBorder:
                            Theme.of(
                              context,
                            ).inputDecorationTheme.focusedBorder,
                      ),
                      onChanged: (value) {
                        setState(() {
                          reasonError = false;
                        });
                      },
                    ),
                    if (reasonError)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Reason field is required.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 30),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _deleteAccount,
                        style: Theme.of(context).elevatedButtonTheme.style,
                        child: const Text(
                          "Confirm Deletion",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isDeleting)
            Stack(
              children: [
                Container(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withOpacity(0.4)
                          : Colors.black.withOpacity(0.14),
                ),
                Container(
                  color: Colors.transparent,
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
    return Platform.isAndroid
        ? SafeArea(top: false, child: scaffold)
        : scaffold;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}
