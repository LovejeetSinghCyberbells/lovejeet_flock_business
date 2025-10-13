import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class EditStaffMemberScreen extends StatefulWidget {
  final String staffId;

  const EditStaffMemberScreen({super.key, required this.staffId});

  @override
  State<EditStaffMemberScreen> createState() => _EditStaffMemberScreenState();
}

class Design {
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);
}

class _EditStaffMemberScreenState extends State<EditStaffMemberScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<String> _selectedVenues = [];
  List<String> _selectedPermissions = [];
  List<dynamic> _venueList = [];
  List<dynamic> _permissionList = [];
  String? _currentImageUrl;
  String? _phoneError;

  File? _pickedImage;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Validation error messages
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _venuesError;

  @override
  void initState() {
    super.initState();
    _fetchStaffData();
  }

  Future<void> _fetchStaffData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final dio = Dio();

    try {
      final response = await dio.get(
        'https://api.getflock.io/api/vendor/teams/${widget.staffId}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      print(
        "Selected Permissions while editing staff member : $_selectedPermissions",
      );
      if (response.statusCode == 200) {
        final data = response.data['data'];
        _firstNameController.text = data["first_name"] ?? '';
        _lastNameController.text = data["last_name"] ?? '';
        _emailController.text = data["email"] ?? '';
        _phoneController.text = data["contact"] ?? '';
        _currentImageUrl = data["image"];

        _selectedVenues =
            (data["assigned_venues"] as List<dynamic>?)
                ?.map((venue) => venue["id"].toString())
                .toList() ??
            [];
        _selectedPermissions =
            (data["permissions"] as List<dynamic>?)
                ?.map((permission) => permission["id"].toString())
                .toList() ??
            [];
      } else {
        _showError("Failed to load staff data. Status: ${response.statusCode}");
      }

      final venueResponse = await dio.get(
        'https://api.getflock.io/api/vendor/venues',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (venueResponse.statusCode == 200) {
        _venueList = venueResponse.data['data'] ?? [];
      }

      final permissionResponse = await dio.get(
        'https://api.getflock.io/api/vendor/permissions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      if (permissionResponse.statusCode == 200) {
        _permissionList = permissionResponse.data['data'] ?? [];
      }

      setState(() {});
    } catch (e) {
      _showError("Error fetching staff data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.photo_camera,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  title: Text(
                    'Take a Photo',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                    );
                    if (pickedFile != null) {
                      setState(() {
                        _pickedImage = File(pickedFile.path);
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedFile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      setState(() {
                        _pickedImage = File(pickedFile.path);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _submitForm() async {
    setState(() {
      _firstNameError = null;
      _lastNameError = null;
      _emailError = null;
      _phoneError = null;
      _venuesError = null;
    });

    // Validate required fields
    bool hasError = false;
    if (_firstNameController.text.isEmpty) {
      setState(() {
        _firstNameError = 'First name is required';
      });
      hasError = true;
    }
    if (_lastNameController.text.isEmpty) {
      setState(() {
        _lastNameError = 'Last name is required';
      });
      hasError = true;
    }
    if (_phoneController.text.isEmpty) {
      setState(() {
        _phoneError = 'Phone number is required';
      });
      hasError = true;
    } else if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(_phoneController.text)) {
      setState(() {
        _phoneError = 'Incorrect phone number format';
      });
      hasError = true;
    }

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      hasError = true;
    } else if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(_emailController.text)) {
      setState(() {
        _emailError = 'Incorrect email format';
      });
      hasError = true;
    }
    if (_selectedVenues.isEmpty) {
      setState(() {
        _venuesError = 'Please assign at least one venue';
      });
      hasError = true;
    }
    if (hasError) {
      return;
    }

    if (_selectedPermissions.contains('2') == false) {
      _selectedPermissions.add('2');
    }

    if (_selectedPermissions.contains('7') ||
        _selectedPermissions.contains('8') ||
        _selectedPermissions.contains('9')) {
      _selectedPermissions.add('6');
    }

    if (_selectedPermissions.contains('18') ||
        _selectedPermissions.contains('19') ||
        _selectedPermissions.contains('20')) {
      _selectedPermissions.add('17');
    }
    // _firstNameController.text.isEmpty ||
    if (_emailController.text.isEmpty) {
      _showError("Please fill in the required fields.");
      return;
    }
    if (_phoneController.text.isEmpty) {
      setState(() {
        _phoneError = 'Phone number is required';
      });
      return;
    } else if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(_phoneController.text)) {
      setState(() {
        _phoneError = 'Incorrect phone number format';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';
      final dio = Dio();

      Map<String, dynamic> formDataMap = {
        "first_name": _firstNameController.text,
        "last_name": _lastNameController.text,
        "email": _emailController.text,
        "contact": _phoneController.text,
      };

      if (_passwordController.text.isNotEmpty) {
        formDataMap["password"] = _passwordController.text;
      }

      for (var i = 0; i < _selectedPermissions.length; i++) {
        formDataMap["permission_ids[$i]"] = _selectedPermissions[i];
      }

      for (var i = 0; i < _selectedVenues.length; i++) {
        formDataMap["venue_ids[$i]"] = _selectedVenues[i];
      }

      if (_pickedImage != null) {
        formDataMap["image"] = await MultipartFile.fromFile(
          _pickedImage!.path,
          filename: p.basename(_pickedImage!.path),
        );
      }

      FormData formData = FormData.fromMap(formDataMap);

      final response = await dio.post(
        'https://api.getflock.io/api/vendor/teams/${widget.staffId}',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              "Member updated successfully!",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorMessage = response.data['message'] ?? 'Unknown error';
        _showError(errorMessage);
      }
    } catch (e) {
      _showError('Error updating member: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    bool hasError = false;
    if (message == "The contact field format is invalid.") {
      setState(() {
        _phoneError = 'Please Enter a valid number.';
      });
      hasError = true;
    }
    if (message == "There is already an account with this email!") {
      setState(() {
        _emailError = "Email already exists.";
      });
      hasError = true;
    }
    if (hasError) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design.darkBackground
              : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Design.darkBackground
                : Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/back_updated.png', height: 40, width: 34),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Member',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge!.color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body:
          _isLoading
              ? Stack(
                children: [
                  Container(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.7)
                            : Colors.white.withOpacity(0.7),
                  ),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Design.darkBorder
                                        : Colors.grey.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Design.darkSurface
                                      : Theme.of(context).colorScheme.surface,
                              backgroundImage:
                                  _pickedImage != null
                                      ? FileImage(_pickedImage!)
                                      : (_currentImageUrl != null
                                          ? NetworkImage(_currentImageUrl!)
                                              as ImageProvider
                                          : null),
                              child:
                                  (_pickedImage == null &&
                                          _currentImageUrl == null)
                                      ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color:
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white70
                                                : Theme.of(
                                                  context,
                                                ).iconTheme.color,
                                      )
                                      : null,
                            ),
                          ),
                          Positioned(
                            bottom: -4,
                            right: -7,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: IconButton(
                                icon: Icon(
                                  Icons.camera_alt,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 18,
                                ),
                                onPressed: _pickImage,
                                padding: EdgeInsets.zero,
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
                        // ===== FIRST NAME FIELD =====
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _firstNameController,
                                decoration: _getInputDecoration('First Name'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty &&
                                      _firstNameError != null) {
                                    setState(() {
                                      _firstNameError = null;
                                    });
                                  }
                                },
                              ),
                              if (_firstNameError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _firstNameError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ===== LAST NAME FIELD =====
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _lastNameController,
                                decoration: _getInputDecoration('Last Name'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty &&
                                      _lastNameError != null) {
                                    setState(() {
                                      _lastNameError = null;
                                    });
                                  }
                                },
                              ),
                              if (_lastNameError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _lastNameError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _emailController,
                      decoration: _getInputDecoration('Email'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && _emailError != null) {
                          setState(() {
                            _emailError = null;
                          });
                        }
                      },
                    ),
                    if (_emailError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _emailError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),
                    TextField(
                      keyboardType: TextInputType.phone,
                      controller: _phoneController,
                      decoration: _getInputDecoration('Phone'),
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && _phoneError != null) {
                          setState(() {
                            _phoneError = null;
                          });
                        }
                      },
                    ),
                    if (_phoneError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _phoneError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      decoration: _getInputDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDropdownField(
                      label: 'Venues',
                      items: _venueList,
                      selectedValues: _selectedVenues,
                      onConfirm: (values) {
                        setState(() {
                          _selectedVenues = values;
                          _venuesError = null;
                        });
                      },
                      errorText: _venuesError,
                    ),
                    const SizedBox(height: 15),
                    _buildDropdownField(
                      label: 'Permissions',
                      items: _permissionList,
                      selectedValues: _selectedPermissions,
                      onConfirm: (values) {
                        setState(() {
                          _selectedPermissions = values;
                        });
                      },
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  InputDecoration _getInputDecoration(String label) {
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<dynamic> items,
    required List<String> selectedValues,
    required Function(List<String>) onConfirm,
    String? errorText,
  }) {
    final isPermissions = label.toLowerCase().contains('permission');
    return InkWell(
      onTap: () async {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            List<String> tempSelected = List.from(selectedValues);
            bool selectAll =
                items.isNotEmpty &&
                items.every(
                  (item) => tempSelected.contains(item['id'].toString()),
                );
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Design.darkSurface
                          : Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Design.darkBorder
                              : Colors.grey.withOpacity(0.2),
                    ),
                  ),
                  title: Text(
                    "Select $label",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.titleLarge!.color,
                    ),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isPermissions)
                          CheckboxListTile(
                            title: const Text('Select All'),
                            value: selectAll,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  tempSelected =
                                      items
                                          .map((item) => item['id'].toString())
                                          .toList();
                                } else {
                                  tempSelected.clear();
                                }
                                selectAll = value ?? false;
                              });
                            },
                          ),
                        if (isPermissions) const Divider(),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final id = item['id'].toString();
                              final name = item['name'].toString();
                              final isSelected = tempSelected.contains(id);
                              return Container(
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.1)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyLarge!.color,
                                      fontSize: 15,
                                    ),
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor:
                                        Theme.of(context).colorScheme.primary,
                                    onChanged: (bool? value) {
                                      setStateDialog(() {
                                        if (value == true) {
                                          tempSelected.add(id);
                                        } else {
                                          tempSelected.remove(id);
                                        }
                                        selectAll =
                                            items.isNotEmpty &&
                                            items.every(
                                              (item) => tempSelected.contains(
                                                item['id'].toString(),
                                              ),
                                            );
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        onConfirm(tempSelected);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: InputDecorator(
              decoration: _getInputDecoration(label),
              baseStyle: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedValues.isEmpty
                          ? 'Select $label'
                          : items
                              .where(
                                (item) => selectedValues.contains(
                                  item['id'].toString(),
                                ),
                              )
                              .map((item) => item['name'].toString())
                              .join(', '),
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            selectedValues.isEmpty
                                ? Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[700]
                                : Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[700],
                  ),
                ],
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
