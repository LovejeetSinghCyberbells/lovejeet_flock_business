import 'dart:convert';
import 'dart:io';
import 'package:flock/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  // State variables for venues
  List<Map<String, dynamic>> _venues = [];
  Map<String, dynamic>? _selectedVenue;
  bool _isLoading = true;
  bool _isSubmitting = false; // For showing loading state during API call
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchVenues();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> fetchVenues() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Authentication failed. Please login again.';
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final url = Uri.parse('https://api.getflock.io/api/vendor/venues');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            _venues = List<Map<String, dynamic>>.from(data['data']);
            // Add a default "Choose Venue" option
            _venues.insert(0, {'id': -1, 'name': 'Choose Venue'});
            _selectedVenue = _venues[0]; // Default to "Choose Venue"
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'No venues found.';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: Unable to fetch venues.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> sendNotification() async {
    // Validate fields
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 25),
          content: Text('Please enter a title.'),
        ),
      );
      return;
    }
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 25),
          content: Text('Please enter a message.'),
        ),
      );
      return;
    }
    if (_selectedVenue?['id'] == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 25),
          content: Text('Please select a venue.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Authentication failed. Please login again.';
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.getflock.io/api/vendor/notifications/send',
      );
      var request = http.MultipartRequest('POST', url);

      // Add form-data fields
      request.fields['title'] = _titleController.text;
      request.fields['message'] = _messageController.text;
      request.fields['venue_id'] = _selectedVenue!['id'].toString();

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseJson = jsonDecode(responseBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseJson['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 25,
              ),
              content: Text('Notification sent successfully!'),
            ),
          );
          // Clear the form
          _titleController.clear();
          _messageController.clear();
          setState(() {
            _selectedVenue = _venues[0]; // Reset to "Choose Venue"
          });
        } else {
          setState(() {
            _errorMessage =
                responseJson['message'] ?? 'Failed to send notification.';
          });
        }
      } else {
        setState(() {
          _errorMessage =
              'Error ${response.statusCode}: ${responseJson['message'] ?? 'Failed to send notification.'}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppConstants.customAppBar(
        context: context,
        title: 'Send Notification',
        // Optionally, if you want a different back icon, you can pass:
        // backIconAsset: 'assets/your_custom_back.png',
      ), // 'ba
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : fetchVenues,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: "Enter title",
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Message field (multiline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: "Enter message",
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Venue dropdown
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white12, // Background of closed dropdown
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.white, // dropdown background
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          child: DropdownButton<Map<String, dynamic>>(
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // 👈 for dropdown menu corners
                            dropdownColor: Colors.white,
                            value: _selectedVenue,
                            icon: const Icon(Icons.keyboard_arrow_down),
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            items:
                                _venues.map((Map<String, dynamic> venue) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: venue,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Text(
                                        venue['name'] ?? 'Unknown Venue',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedVenue = newValue ?? _selectedVenue;
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Send button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : sendNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(
                            255,
                            130,
                            16,
                            1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isSubmitting
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : const Text(
                                  "Send",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
    );
    return Platform.isAndroid
        ? SafeArea(top: false, child: scaffold)
        : scaffold;
  }
}
