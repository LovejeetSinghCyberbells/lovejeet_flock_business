import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flock/app_colors.dart';

// Add Design class for dark mode colors
class Design {
  static const Color darkBackground = Color(
    0xFF1A1A1A,
  ); // Professional dark black
  static const Color darkSurface = Color(
    0xFF242424,
  ); // Slightly lighter surface
  static const Color darkCard = Color(0xFF2A2A2A); // Card background
  static const Color darkBorder = Color(0xFF2C2C2C); // Subtle border color
  static const Color darkDivider = Color(0xFF383838); // Divider color
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Report Screen Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          surface: Colors.white,
          onSurface: Colors.black,
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      darkTheme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          surface: Design.darkSurface,
          onSurface: Colors.white,
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: Design.darkBackground,
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white),
          bodySmall: TextStyle(fontSize: 12, color: Colors.white),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 4,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const ReportScreen(),
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> _venues = [];
  Map<String, dynamic>? _selectedVenue;
  List<String> _reportTypes = [];
  String? _selectedReportType;

  bool _showVenueDropdown = false;
  bool _showReportTypeDropdown = false;

  final TextEditingController _descriptionController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchVenues();
    _fetchReportTypes();
  }

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchVenues() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No token found. Please login again.';
      });
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/venues');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          final List<dynamic> venueData = data['data'];
          setState(() {
            _venues =
                venueData
                    .map(
                      (venue) => {
                        'id': venue['id'],
                        'name': venue['name']?.toString() ?? 'Unnamed Venue',
                      },
                    )
                    .toList();
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load venues.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error ${response.statusCode} loading venues.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _fetchReportTypes() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No token found. Please login again.';
      });
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/report-types');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print("Report types API response: ${response.body}");
        final data = json.decode(response.body);

        if (data is Map &&
            data['status'] == 'success' &&
            data['data'] != null) {
          final List<dynamic> reportTypeData = data['data'];
          setState(() {
            _reportTypes =
                reportTypeData.map((rt) => rt['label'].toString()).toList();
          });
        } else if (data is List) {
          setState(() {
            _reportTypes = data.map((rt) => rt['label'].toString()).toList();
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to load report types.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error ${response.statusCode} loading report types.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Future<void> _submitReport() async {
    if (_selectedVenue == null) {
      setState(() {
        _errorMessage = 'Please select a venue.';
      });
      return;
    }
    if (_selectedReportType == null) {
      setState(() {
        _errorMessage = 'Please select a report type.';
      });
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a description.';
      });
      return;
    }

    setState(() => _errorMessage = '');

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No token found. Please login again.';
      });
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/feedbacks');
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['venue_id'] = _selectedVenue!['id'].toString();
      request.fields['report_type'] = _selectedReportType ?? '';
      request.fields['description'] = _descriptionController.text.trim();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              content: Text(
                responseData['message'] ?? 'Report submitted!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          );
          Navigator.pop(context);
        } else {
          setState(() {
            _errorMessage =
                responseData['message'] ?? 'Failed to submit report.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }
  }

  Widget customVenueDropdown() {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Design.darkCard
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBorder
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showVenueDropdown = !_showVenueDropdown;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Design.darkCard
                        : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedVenue == null
                        ? "Select Venue"
                        : _selectedVenue!['name'] ?? "Select Venue",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                  Icon(
                    _showVenueDropdown
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          if (_showVenueDropdown)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Design.darkCard
                        : Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
                border: Border.all(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Design.darkBorder
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _venues.length,
                        itemBuilder: (context, index) {
                          final venue = _venues[index];
                          final isSelected =
                              _selectedVenue != null &&
                              _selectedVenue!['id'].toString() ==
                                  venue['id'].toString();
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedVenue = venue;
                                _showVenueDropdown = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              color:
                                  isSelected
                                      ? Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.primary.withOpacity(0.2)
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                              child: Text(
                                venue['name'] ?? '',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget customReportTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Design.darkCard
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design.darkBorder
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showReportTypeDropdown = !_showReportTypeDropdown;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Design.darkCard
                        : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedReportType == null
                        ? "Select Report Type"
                        : _selectedReportType!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                  ),
                  Icon(
                    _showReportTypeDropdown
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          if (_showReportTypeDropdown)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Design.darkCard
                        : Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
                border: Border.all(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Design.darkBorder
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _reportTypes.length,
                        itemBuilder: (context, index) {
                          final rt = _reportTypes[index];
                          final isSelected =
                              _selectedReportType != null &&
                              _selectedReportType == rt;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedReportType = rt;
                                _showReportTypeDropdown = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              color:
                                  isSelected
                                      ? Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.primary.withOpacity(0.2)
                                          : Theme.of(
                                            context,
                                          ).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                              child: Text(
                                rt,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Design
                  .darkBackground // Professional dark black
              : Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Container(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Design
                      .darkBackground // Professional dark black
                  : Theme.of(context).scaffoldBackgroundColor,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Design
                                .darkBackground // Professional dark black
                            : Theme.of(context).scaffoldBackgroundColor,
                    child: Row(
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
                              "Report",
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Choose venue",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.87)
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  customVenueDropdown(),
                  const SizedBox(height: 16),
                  Text(
                    "Choose report type",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.87)
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  customReportTypeDropdown(),
                  const SizedBox(height: 16),
                  Text(
                    "Description",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.87)
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter description",
                      hintStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      fillColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Design.darkCard
                              : Theme.of(context).colorScheme.surface,
                      filled: true,
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Design.darkBorder
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        elevation:
                            Theme.of(context).brightness == Brightness.dark
                                ? 4
                                : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Submit",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
