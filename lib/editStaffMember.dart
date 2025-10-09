import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'constants.dart';

class EditStaffMemberScreen extends StatefulWidget {
  final Map<String, dynamic> staffMember;
  const EditStaffMemberScreen({super.key, required this.staffMember});

  @override
  State<EditStaffMemberScreen> createState() => _EditStaffMemberScreenState();
}

class _EditStaffMemberScreenState extends State<EditStaffMemberScreen> {
  List<dynamic> _permissionList = [];
  List<String> _selectedPermissions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPermissions();
    // Initialize selected permissions from staffMember
    if (widget.staffMember['permissions'] != null) {
      _selectedPermissions = List<String>.from(
        (widget.staffMember['permissions'] as List).map(
          (p) => p['id'].toString(),
        ),
      );
    }
  }

  Future<void> _fetchPermissions() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final dio = Dio();
    try {
      final response = await dio.get(
        'https://api.getflock.io/api/vendor/permissions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _permissionList = response.data['data'] ?? [];
        });
      }
    } catch (e) {
      // Handle error if needed
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Staff Member')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... other fields ...
                    Text(
                      'Permissions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    AppConstants.assignPermissionsDropdown(
                      context: context,
                      permissionList: _permissionList,
                      selectedPermissions: _selectedPermissions,
                      onConfirm: (values) {
                        setState(() {
                          _selectedPermissions = values;
                        });
                      },
                    ),
                    // ... other fields ...
                  ],
                ),
              ),
    );
  }
}
