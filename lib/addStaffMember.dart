import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flock/constants.dart';

class AddMemberScreen extends StatefulWidget {
  final Map<String, String>? existingMember;
  const AddMemberScreen({super.key, this.existingMember});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class Design {
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF3E3E3E);
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  bool _obscurePassword = true;
  List<String> _selectedVenues = [];
  List<String> _selectedPermissions = [];

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<dynamic> _venueList = [];
  List<dynamic> _permissionList = [];
  File? _pickedImage;
  bool _isLoading = false;

  // Validation error messages
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _venuesError;

  @override
  void initState() {
    super.initState();
    if (widget.existingMember != null) {
      _firstNameController.text = widget.existingMember!['firstName'] ?? '';
      _lastNameController.text = widget.existingMember!['lastName'] ?? '';
      _emailController.text = widget.existingMember!['email'] ?? '';
      _phoneController.text = widget.existingMember!['phone'] ?? '';
      _selectedVenues = widget.existingMember!['venue']?.split(',') ?? [];
      _selectedPermissions =
          widget.existingMember!['permission']?.split(',') ?? [];
      if (!_selectedPermissions.contains('2')) {
        _selectedPermissions.add('2');
      }
    } else {
      _selectedPermissions = ['2'];
    }
    fetchDropdownData();
  }

  Future<void> fetchDropdownData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final dio = Dio();

    try {
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
        setState(() {
          _venueList = venueResponse.data['data'] ?? [];
        });
      }
    } catch (e) {
      _showError('Error fetching venues');
    }

    try {
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
        setState(() {
          _permissionList = permissionResponse.data['data'] ?? [];
          if (_permissionList.any((p) => p['id'].toString() == '2') &&
              !_selectedPermissions.contains('2')) {
            _selectedPermissions.add('2');
          }
        });
      }
    } catch (e) {
      _showError('Error fetching permissions');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitForm() async {
    // Reset error messages
    setState(() {
      _firstNameError = null;
      _lastNameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
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
    if (_passwordController.text.isEmpty && widget.existingMember == null) {
      setState(() {
        _passwordError = 'Password is required';
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

    // Ensure id=2 is always included
    if (!_selectedPermissions.contains('2')) {
      _selectedPermissions.add('2');
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      Map<String, dynamic> formDataMap = {
        "first_name": _firstNameController.text,
        "last_name": _lastNameController.text,
        "email": _emailController.text,
        "contact": _phoneController.text,
        if (_passwordController.text.isNotEmpty)
          "password": _passwordController.text,
      };

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

      final dio = Dio();
      final String url =
          widget.existingMember != null && widget.existingMember!['id'] != null
              ? "https://api.getflock.io/api/vendor/teams/${widget.existingMember!['id']}"
              : "https://api.getflock.io/api/vendor/teams";

      final response = await dio.post(
        url,
        data: formData,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "Accept": "application/json",
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              content: Text(
                widget.existingMember != null
                    ? "Member updated successfully!"
                    : "Member added successfully!",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final errorMessage = response.data['message'] ?? 'Unknown error';
        final errors =
            response.data['errors']?.toString() ?? 'No details provided';
        print('API error: ${response.data}');
        _showError('${'Failed to save member: ' + errorMessage}\n$errors');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error saving member');
    }
  }

  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red, // <-- This is pure red
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  InputDecoration _getInputDecoration(String label, {String? errorText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      filled: Theme.of(context).brightness == Brightness.dark,
      fillColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design.darkSurface
              : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      isDense: true,
      errorText: errorText,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required List<dynamic> items,
    required List<String> selectedValues,
    required Function(List<String>) onConfirm,
    bool showChips = true,
    String? mandatoryId,
    String? errorText,
  }) {
    return InkWell(
      onTap: () async {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            List<String> tempSelected = List.from(selectedValues);
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
                  content:
                      items.isEmpty
                          ? SizedBox(
                            width: double.maxFinite,
                            height: 60, // Shorter height
                            child: Center(
                              child: Text(
                                'No venues added yet',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13, // Smaller font
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          : SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final id = item['id'].toString();
                                final name = item['name'].toString();
                                final isSelected = tempSelected.contains(id);
                                final isMandatoryItem =
                                    mandatoryId != null && id == mandatoryId;

                                return Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1)
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
                                    trailing:
                                        isMandatoryItem
                                            ? Icon(
                                              Icons.check_circle,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              size: 20,
                                            )
                                            : Checkbox(
                                              value: isSelected,
                                              activeColor:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              onChanged: (bool? value) {
                                                if (value != null) {
                                                  setStateDialog(() {
                                                    if (value) {
                                                      tempSelected.add(id);
                                                    } else {
                                                      tempSelected.remove(id);
                                                    }
                                                  });
                                                }
                                              },
                                            ),
                                    enabled: !isMandatoryItem,
                                  ),
                                );
                              },
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
                    if (items.isNotEmpty)
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: InputDecorator(
          decoration: _getInputDecoration(label, errorText: errorText),
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
                            (item) =>
                                selectedValues.contains(item['id'].toString()),
                          )
                          .map((item) => item['name'].toString())
                          .join(', '),
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        selectedValues.isEmpty
                            ? Theme.of(context).brightness == Brightness.dark
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
    );
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
          'Add Member',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge!.color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
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
                                Theme.of(context).brightness == Brightness.dark
                                    ? Design.darkBorder
                                    : Colors.grey.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Design.darkSurface
                                  : Theme.of(context).colorScheme.surface,
                          backgroundImage:
                              _pickedImage != null
                                  ? FileImage(_pickedImage!)
                                  : null,
                          child:
                              _pickedImage == null
                                  ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Theme.of(context).iconTheme.color,
                                  )
                                  : null,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: -5,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 18,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (BuildContext context) {
                                  return SafeArea(
                                    child: Wrap(
                                      children: [
                                        ListTile(
                                          leading: const Icon(
                                            Icons.photo_library,
                                          ),
                                          title: const Text(
                                            'Choose from Gallery',
                                          ),
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            _pickImage(ImageSource.gallery);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.camera_alt),
                                          title: const Text('Take a Photo'),
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            _pickImage(ImageSource.camera);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Flexible(
                      child: TextField(
                        controller: _firstNameController,
                        decoration: _getInputDecoration(
                          'First Name',
                          errorText: _firstNameError,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && _firstNameError != null) {
                            setState(() {
                              _firstNameError = null;
                            });
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        decoration: _getInputDecoration(
                          'Last Name',
                          errorText: _lastNameError,
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && _lastNameError != null) {
                            setState(() {
                              _lastNameError = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  decoration: _getInputDecoration(
                    'Email',
                    errorText: _emailError,
                  ),
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
                const SizedBox(height: 15),
                TextField(
                  controller: _phoneController,
                  decoration: _getInputDecoration(
                    'Phone',
                    errorText: _phoneError,
                  ),
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
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  decoration: _getInputDecoration(
                    'Password',
                    errorText: _passwordError,
                  ).copyWith(
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
                  onChanged: (value) {
                    if (value.isNotEmpty && _passwordError != null) {
                      setState(() {
                        _passwordError = null;
                      });
                    }
                  },
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

                const SizedBox(height: 8),
                // Text(
                //   'Permissions',
                //   style: Theme.of(context).textTheme.titleMedium,
                // ),
                const SizedBox(height: 8),
                _buildDropdownField(
                  label: 'Permissions',
                  items: _permissionList,
                  selectedValues: _selectedPermissions,
                  onConfirm: (values) {
                    setState(() {
                      _selectedPermissions = values;
                    });
                  },
                  showChips: false,
                ),
                const SizedBox(height: 40),
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    )
                    : AppConstants.fullWidthButton(
                      text: "Submit",
                      onPressed: _submitForm,
                    ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.7),
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
    );
  }
}
