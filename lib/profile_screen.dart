import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_scaffold.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class Design {
  static const Color primaryColorOrange = Color.fromRGBO(255, 152, 0, 1);
  static const Color black = Colors.black;
  static const Color white = Colors.white;
  static const Color lightPurple = Color(0xFFF0F0F5);
  static const Color errorRed = Colors.red;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : white;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : white;
  }

  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? white : black;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : Colors.grey.withOpacity(0.3);
  }
}

class TabProfile extends StatefulWidget {
  const TabProfile({super.key});

  @override
  _TabProfileState createState() => _TabProfileState();
}

class _TabProfileState extends State<TabProfile> {
  String? userId;
  bool isLoading = false;
  String firstName = '';
  String lastName = '';
  String email = '';
  String profilePic = '';

  @override
  void initState() {
    super.initState();
    detailFunc();
  }

  Future<void> detailFunc() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('access_token');

    if (token == null) {
      Fluttertoast.showToast(msg: 'Please log in to view profile');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(
          msg: 'No internet connection',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
      print("Hiiiiiiiiiiiiiii112221122");
      final response = await http.get(
        Uri.parse('https://api.getflock.io/api/vendor/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print("Response from profile api: ${response.body}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = data['data'];

        setState(() {
          firstName = profile['first_name'] ?? 'John';
          lastName = profile['last_name'] ?? 'Doe';
          email = profile['email'] ?? 'johndoe@example.com';
          profilePic = profile['image'] ?? '';
          isLoading = false;
        });

        await prefs.setString('firstName', firstName);
        await prefs.setString('lastName', lastName);
        await prefs.setString('email', email);
        await prefs.setString('profilePic', profilePic);

        print("Profile loaded: $firstName $lastName, $email");
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to fetch profile. Please login again.',
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on SocketException {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'No internet connection',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      print("Error fetching profile: $e");
      Fluttertoast.showToast(msg: 'Something went wrong.');
      setState(() {
        isLoading = false;
      });
    }
  }

  void logoutButton() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('isLoggedIn', false);

    Navigator.pushReplacementNamed(context, '/login');
    Fluttertoast.showToast(msg: 'Logged out successfully');
  }

  Widget _buildProfileOption({
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Design.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Design.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        minVerticalPadding: 6,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Design.getTextColor(context),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Design.getTextColor(context).withOpacity(0.5),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      currentIndex: 4,
      body: Container(
        color: Design.getBackgroundColor(context),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: Text(
                        "My Profile",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Design.getTextColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Design.getSurfaceColor(context),
                        child:
                            profilePic.isEmpty
                                ? Image.asset(
                                  'assets/profile.png',
                                  width: 40,
                                  height: 70,
                                  fit: BoxFit.cover,
                                )
                                : ClipOval(
                                  child: Image.network(
                                    profilePic,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        color: Design.getSurfaceColor(context),
                                        child: Center(
                                          child: Image.asset(
                                            'assets/profile.png',
                                            width: 60,
                                            height: 60,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print("Error loading profile image");
                                      return Image.asset(
                                        'assets/profile.png',
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      (firstName.isEmpty && lastName.isEmpty)
                          ? 'User Name'
                          : "$firstName $lastName".trim(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Design.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email.isEmpty ? 'Email not available' : email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Design.getTextColor(context).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        _buildProfileOption(
                          title: "Profile Settings",
                          onTap: () async {
                            final updatedProfile = await Navigator.pushNamed(
                              context,
                              '/EditProfile',
                              arguments: {
                                'firstName': firstName,
                                'lastName': lastName,
                                'email': email,
                                'profilePic': profilePic,
                              },
                            );
                            if (updatedProfile != null &&
                                updatedProfile is Map<String, dynamic>) {
                              detailFunc();
                            }
                          },
                        ),
                        _buildProfileOption(
                          title: "Staff Management",
                          onTap:
                              () =>
                                  Navigator.pushNamed(context, '/staffManage'),
                        ),
                        _buildProfileOption(
                          title: "Change Password",
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/changePassword',
                              ),
                        ),
                        _buildProfileOption(
                          title: "Transaction History",
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/HistoryScreen',
                              ),
                        ),
                        _buildProfileOption(
                          title: "Open Hours",
                          onTap:
                              () => Navigator.pushNamed(context, '/openHours'),
                        ),
                        _buildProfileOption(
                          title: "How to ?",
                          onTap:
                              () => Navigator.pushNamed(context, '/tutorials'),
                        ),
                        _buildProfileOption(
                          title: "Feedback",
                          onTap:
                              () => Navigator.pushNamed(context, '/feedback'),
                        ),
                        _buildProfileOption(
                          title: "Delete Account",
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/DeleteAccount',
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 38),
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: logoutButton,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(
                            255,
                            130,
                            16,
                            1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Log Out",
                          style: TextStyle(
                            color: Design.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Design.getSurfaceColor(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Design.primaryColorOrange,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
