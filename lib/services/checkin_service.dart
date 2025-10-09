import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CheckinService {
  static final CheckinService _instance = CheckinService._internal();
  factory CheckinService() => _instance;
  CheckinService._internal();

  Future<bool> performCheckIn(String venueId, BuildContext? context) async {
    try {
      // Get user token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Please log in to check in',
          toastLength: Toast.LENGTH_SHORT,
        );
        return false;
      }

      // Make API call to check in
      final url = Uri.parse(
        'https://api.getflock.io/api/vendor/verify-voucher',
      );
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'qr_code': venueId, 'venue_id': venueId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          Fluttertoast.showToast(
            msg: 'Successfully checked in to venue!',
            toastLength: Toast.LENGTH_LONG,
          );
          return true;
        } else {
          Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Check-in failed',
            toastLength: Toast.LENGTH_SHORT,
          );
          return false;
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to check in. Please try again.',
          toastLength: Toast.LENGTH_SHORT,
        );
        return false;
      }
    } catch (e) {
      print('Error performing check-in: $e');
      Fluttertoast.showToast(
        msg: 'Error performing check-in. Please try again.',
        toastLength: Toast.LENGTH_SHORT,
      );
      return false;
    }
  }
}
