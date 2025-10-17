import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flock/constants.dart'; // Adjust the import path as needed.

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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController passwordController;

  String profilePic = "";
  bool _isLoading = false;
  bool _isUpdating = false;
  String _errorMessage = '';
  File? _selectedImage;
  String? firstNameError;
  String? lastNameError;
  String? phoneNumberError;

  final bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    emailController = TextEditingController();
    phoneController = TextEditingController();
    passwordController = TextEditingController();
    _fetchProfile();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No token found. Please login again.';
      });
      Fluttertoast.showToast(msg: _errorMessage);
      return;
    }

    const String profileUrl = 'https://api.getflock.io/api/vendor/profile';
    try {
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint("Profile Fetch Response Status: ${response.statusCode}");
      debugPrint("Profile Fetch Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final userData = data['data'];
          setState(() {
            firstNameController.text = userData['first_name'] ?? '';
            lastNameController.text = userData['last_name'] ?? '';
            emailController.text = userData['email'] ?? '';
            phoneController.text = userData['contact'] ?? '';
            profilePic = userData['image'] ?? '';
            _isLoading = false;
          });

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('firstName', userData['first_name'] ?? '');
          await prefs.setString('lastName', userData['last_name'] ?? '');
          await prefs.setString('email', userData['email'] ?? '');
          await prefs.setString('profilePic', userData['image'] ?? '');
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = data['message'] ?? 'Failed to fetch profile.';
          });
          Fluttertoast.showToast(msg: _errorMessage);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to fetch profile. Please try again.';
        });
        Fluttertoast.showToast(msg: _errorMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error: No internet connection';
      });
      Fluttertoast.showToast(msg: _errorMessage);
    }
  }

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      Fluttertoast.showToast(
        msg:
            'Camera permission is permanently denied. Please enable it in settings.',
      );
      await openAppSettings();
      return false;
    } else {
      Fluttertoast.showToast(msg: 'Camera permission denied.');
      return false;
    }
  }

  Future<void> _selectImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Choose from Gallery',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: Text(
                  'Take a Photo',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  bool hasPermission = await _requestCameraPermission();
                  if (hasPermission) {
                    _pickImage(ImageSource.camera);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final contact = phoneController.text.trim();

    if (firstName.isEmpty && lastName.isEmpty) {
      setState(() {
        lastNameError = "Last name is required.";
        firstNameError = "First name is required.";
      });
      return;
    } else if (firstName.isEmpty) {
      setState(() {
        firstNameError = "First name is required.";
      });
      return;
    } else if (lastName.isEmpty) {
      setState(() {
        lastNameError = "Last name is required.";
      });
      return;
    } else if (contact.isNotEmpty &&
        !RegExp(r'^\+?[0-9]{10}$').hasMatch(contact)) {
      setState(() {
        phoneNumberError = 'Invalid phone number.';
      });
      return;
    } else {
      setState(() {
        lastNameError = null;

        firstNameError = null;
        phoneNumberError = null;
      });
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = '';
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _isUpdating = false;
      });
      Fluttertoast.showToast(msg: "No token found. Please login again.");
      return;
    }

    final url = Uri.parse("https://api.getflock.io/api/vendor/profile/update");

    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['first_name'] = firstName;
      request.fields['last_name'] = lastName;
      request.fields['email'] = email;
      request.fields['contact'] = contact;

      if (password.isNotEmpty) {
        request.fields['password'] = password;
      }

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _selectedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isUpdating = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 25,
              ),
              backgroundColor: Colors.green,
              content: Text(
                data['message'] ?? 'Profile updated!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          );
          // Fluttertoast.showToast(msg: data['message'] ?? 'Profile updated!');
          String newProfilePic =
              data['data']?['image']?.toString() ?? profilePic;

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('firstName', firstName);
          await prefs.setString('lastName', lastName);
          await prefs.setString('email', email);
          await prefs.setString('profilePic', newProfilePic);

          Navigator.pop(context, {
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
            'profilePic': newProfilePic,
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Profile update failed.';
          });
          Fluttertoast.showToast(msg: _errorMessage);
        }
      } else {
        setState(() {
          _errorMessage = 'Error ${response.statusCode} updating profile.';
        });
        Fluttertoast.showToast(msg: _errorMessage);
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _errorMessage = 'Network error: $e';
      });
      Fluttertoast.showToast(msg: _errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Design.getBackgroundColor(context),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child:
                  _isLoading
                      ? Stack(
                        children: [
                          Container(color: Design.getBackgroundColor(context)),
                          Center(
                            child: Image.asset(
                              'assets/Bird_Full_Eye_Blinking.gif',
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ],
                      )
                      : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                      "Edit Profile",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        color: Design.getTextColor(context),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.black.withOpacity(
                                                    0.3,
                                                  )
                                                  : Colors.black.withOpacity(
                                                    0.1,
                                                  ),
                                          spreadRadius: 1,
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Design.getSurfaceColor(
                                        context,
                                      ),
                                      backgroundImage:
                                          _selectedImage != null
                                              ? FileImage(_selectedImage!)
                                              : (profilePic.isNotEmpty &&
                                                          profilePic.startsWith(
                                                            'http',
                                                          )
                                                      ? NetworkImage(profilePic)
                                                      : null)
                                                  as ImageProvider<Object>?,
                                      child:
                                          (profilePic.isEmpty &&
                                                  _selectedImage == null)
                                              ? Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Design.getTextColor(
                                                  context,
                                                ).withOpacity(0.5),
                                              )
                                              : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Design.getSurfaceColor(context),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Design.getBorderColor(context),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.black.withOpacity(
                                                      0.3,
                                                    )
                                                    : Colors.black.withOpacity(
                                                      0.1,
                                                    ),
                                            spreadRadius: 1,
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color.fromRGBO(
                                          255,
                                          130,
                                          16,
                                          1,
                                        ),
                                        child: IconButton(
                                          onPressed: _selectImage,
                                          icon: Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Design.white,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First Name Field
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTextField(
                                        controller: firstNameController,
                                        hint: 'First Name',
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter first name';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            firstNameError = null;
                                          });
                                        },
                                      ),
                                      if (firstNameError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            firstNameError!,
                                            style: TextStyle(
                                              color: Design.errorRed,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Last Name Field
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildTextField(
                                        controller: lastNameController,
                                        hint: 'Last Name',
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter last name';
                                          }
                                          return null;
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            lastNameError = null;
                                          });
                                        },
                                      ),
                                      if (lastNameError != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            lastNameError!,
                                            style: TextStyle(
                                              color: Design.errorRed,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            _buildTextField(
                              controller: emailController,
                              hint: 'Enter Email Address',
                              readOnly: true,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 25),
                            _buildTextField(
                              controller: phoneController,
                              hint: 'Enter phone number',
                              readOnly: false,
                              keyboardType: TextInputType.phone,
                              onChanged: (value) {
                                setState(() {
                                  phoneNumberError = null;
                                });
                              },
                            ),
                            if (phoneNumberError != null)
                              Align(
                                alignment: AlignmentGeometry.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    phoneNumberError!,
                                    style: TextStyle(
                                      color: Design.errorRed,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 30),
                            if (_errorMessage.isNotEmpty)
                              Align(
                                alignment: AlignmentGeometry.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      color: Design.errorRed,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
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
                                onPressed: _isUpdating ? null : _updateProfile,
                                child:
                                    _isUpdating
                                        ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Design.white,
                                                ),
                                          ),
                                        )
                                        : Text(
                                          'Update',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Design.white,
                                          ),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: TextStyle(color: Design.getTextColor(context), fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Design.getTextColor(context).withOpacity(0.5),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Design.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Design.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Design.primaryColorOrange),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Design.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Design.errorRed),
        ),
      ),
    );
  }
}
