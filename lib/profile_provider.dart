import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProfileProvider with ChangeNotifier {
  String firstName = '';
  String lastName = '';
  String email = '';
  String profilePic = '';
  bool isLoading = false;

  Future<void> fetchProfile(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://api.getflock.io/api/vendor/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Profile response: $data"); // Debug
        firstName = data['first_name'] ?? '';
        lastName = data['last_name'] ?? '';
        email = data['email'] ?? '';
        profilePic = data['profile_pic'] ?? '';
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
