import 'dart:convert';

import 'package:flock/editSatffMember.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'addStaffMember.dart';
import 'package:intl/intl.dart';
import 'package:flock/app_colors.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class Design {
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF242424);
  static const Color darkBorder = Color(0xFF2C2C2C);
  static const Color darkCard = Color(0xFF2A2A2A);
  static const Color darkDivider = Color(0xFF383838);
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<Map<String, String>> staffMembers = [];
  String? _authToken;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchStaff();
    _initializePermissions();
  }

  /* --------- permissions section started -----*/
  List<Map<String, dynamic>> permissions = [];
  bool canAddStaffMember = false;
  bool canEditStaffMember = false;
  bool canRemoveStaffMember = false;

  Future<void> fetchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsString = prefs.getString('permissions');

    if (permissionsString != null) {
      final List<dynamic> decoded = jsonDecode(permissionsString);
      permissions = List<Map<String, dynamic>>.from(decoded);

      print('Loaded permissions: $permissions');
    }
  }

  bool hasPermissionToUser(String permissionName) {
    final normalized = permissionName.toLowerCase().replaceAll('_', ' ');

    return permissions.any(
      (p) => (p['name']?.toString().toLowerCase() ?? '') == normalized,
    );
  }

  Future<void> checkPermission() async {
    setState(() {
      if (permissions.isEmpty) {
        print("User has all permissions.");
        canAddStaffMember = true;
        canEditStaffMember = true;
        canRemoveStaffMember = true;

        return;
      }
      canAddStaffMember = hasPermissionToUser('Add staff');
      canEditStaffMember = hasPermissionToUser('Edit staff');
      canRemoveStaffMember = hasPermissionToUser('Remove staff');

      if (canAddStaffMember) print("✅ User can add staff.");
      if (canEditStaffMember) print("✅ User can edit staff member.");
      if (canRemoveStaffMember) print("✅ User can remove staff member.");

      if (!canAddStaffMember && !canEditStaffMember && !canRemoveStaffMember) {
        print("❌ User has no permission to add, edit and remove staff member.");
      }
    });
  }

  Future<void> _initializePermissions() async {
    await fetchPermissions();
    checkPermission();
  }

  /* --------- permissions section endede -----*/

  String formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return 'Not available';
    }
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return dateTimeStr;
    }
  }

  Future<void> _loadTokenAndFetchStaff() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('access_token');
    if (_authToken == null) {
      debugPrint("No token found in SharedPreferences.");
      return;
    }
    await fetchStaffMembers();
  }

  Future<void> fetchStaffMembers() async {
    setState(() => _isLoading = true);
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.getflock.io/api/vendor/teams',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['data'] != null) {
          final List<dynamic> rawList = data['data'];
          final List<Map<String, String>> loadedStaff =
              rawList.map<Map<String, String>>((item) {
                return {
                  "id": item["id"]?.toString() ?? '',
                  "firstName": item["first_name"] ?? '',
                  "lastName": item["last_name"] ?? '',
                  "email": item["email"] ?? '',
                  "phone": item["contact"] ?? '',
                  "createdAt": item["created_at"] ?? '',
                };
              }).toList();

          // Sort staff members by createdAt in descending order (latest first)
          loadedStaff.sort((a, b) {
            final aDate =
                DateTime.tryParse(a["createdAt"] ?? '') ?? DateTime(0);
            final bDate =
                DateTime.tryParse(b["createdAt"] ?? '') ?? DateTime(0);
            return bDate.compareTo(aDate); // Descending order
          });

          setState(() {
            staffMembers = loadedStaff;
          });
        } else {
          debugPrint("No 'data' field found in the response.");
        }
      } else {
        debugPrint("Request failed with status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Exception while fetching staff members: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> addMember() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMemberScreen()),
    );
    if (result == true) {
      await fetchStaffMembers();
    }
  }

  Future<void> editMember(String memberId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStaffMemberScreen(staffId: memberId),
      ),
    );
    if (result == true) {
      await fetchStaffMembers();
    }
  }

  Future<void> deleteMember(int index) async {
    final memberId = staffMembers[index]["id"];
    if (memberId == null || memberId.isEmpty) {
      debugPrint("Cannot delete member: ID is missing.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Cannot delete member: ID is missing.",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      );
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.delete(
        'https://api.getflock.io/api/vendor/teams/$memberId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          staffMembers.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            content: Text(
              "Member deleted successfully!",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        );
      } else {
        final errorMessage = response.data['message'] ?? 'Unknown error';
        debugPrint(
          "Delete request failed with status: ${response.statusCode}, message: $errorMessage",
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              "Failed to delete member: $errorMessage",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Exception while deleting staff member: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            "Error deleting member: $e",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
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
          'Staff Members',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge!.color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      canAddStaffMember == false
                          ? Container()
                          : InkWell(
                            onTap: addMember,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.add_circle,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.primary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Add Member",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AppColors.primary
                                              : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        Container(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Design.darkBackground.withOpacity(0.95)
                                  : Colors.white.withOpacity(0.7),
                          child: Center(
                            child: Image.asset(
                              'assets/Bird_Full_Eye_Blinking.gif',
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                      staffMembers.isEmpty && !_isLoading
                          ? Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              "No Member Found...",
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.7
                                      : 0.6,
                                ),
                                fontSize: 16,
                              ),
                            ),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: staffMembers.length,
                            itemBuilder: (context, index) {
                              final member = staffMembers[index];
                              return Card(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Design.darkCard
                                        : Theme.of(context).colorScheme.surface,
                                elevation:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 3
                                        : 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Design.darkBorder
                                            : Colors.grey.withOpacity(0.2),
                                    width:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 1
                                            : 0.5,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${member["firstName"]} ${member["lastName"]}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    formatDateTime(member["createdAt"]),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? 0.7
                                            : 0.6,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      canEditStaffMember == false
                                          ? Container()
                                          : IconButton(
                                            icon: Image.asset(
                                              'assets/edit.png',
                                              width: 20,
                                              height: 20,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).iconTheme.color,
                                            ),
                                            onPressed: () {
                                              final id = member["id"] ?? "";
                                              if (id.isNotEmpty) {
                                                editMember(id);
                                              }
                                            },
                                          ),
                                      canRemoveStaffMember == false
                                          ? Container()
                                          : IconButton(
                                            icon: Image.asset(
                                              'assets/closebtn.png',
                                              width: 20,
                                              height: 20,
                                            ),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (
                                                  BuildContext context,
                                                ) {
                                                  return AlertDialog(
                                                    backgroundColor:
                                                        Theme.of(
                                                                  context,
                                                                ).brightness ==
                                                                Brightness.dark
                                                            ? Design.darkCard
                                                            : Theme.of(context)
                                                                .colorScheme
                                                                .surface,
                                                    title: Text(
                                                      'Confirm Delete',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.titleLarge?.copyWith(
                                                        color:
                                                            Theme.of(
                                                                      context,
                                                                    ).brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? Colors.white
                                                                : null,
                                                      ),
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete this member?',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodyMedium?.copyWith(
                                                        color:
                                                            Theme.of(
                                                                      context,
                                                                    ).brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? Colors.white
                                                                    .withOpacity(
                                                                      0.87,
                                                                    )
                                                                : Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface,
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.of(
                                                            context,
                                                          ).pop();
                                                        },
                                                        child: Text(
                                                          'CANCEL',
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .labelLarge
                                                              ?.copyWith(
                                                                color: Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      0.7,
                                                                    ),
                                                              ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          deleteMember(index);
                                                          Navigator.of(
                                                            context,
                                                          ).pop();
                                                        },
                                                        child: Text(
                                                          'OK',
                                                          style: Theme.of(
                                                                context,
                                                              )
                                                              .textTheme
                                                              .labelLarge
                                                              ?.copyWith(
                                                                color:
                                                                    Theme.of(
                                                                          context,
                                                                        )
                                                                        .colorScheme
                                                                        .primary,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
