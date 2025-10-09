import 'package:flock/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  _FaqScreenState createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  bool isLoading = true;
  int activeFaq = -1;
  List<dynamic> faqList = [];
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchFaqs();
  }

  // Retrieve the token stored during login
  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Fetch FAQs from the API with authentication
  Future<void> fetchFaqs() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    String? token = await getToken();
    if (token == null || token.isEmpty) {
      // If token is missing, redirect to login
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse('https://api.getflock.io/api/vendor/faqs');

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
        // Check if API responded with a success status and has data
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            faqList = List.from(data['data']);
          });
        } else {
          setState(() {
            errorMessage = 'No FAQs found.';
          });
        }
      } else {
        setState(() {
          errorMessage = 'Error ${response.statusCode}: Unable to fetch FAQs';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: $e';
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  // Toggle the expanded/collapsed state for an FAQ item
  void toggleFaq(int id) {
    setState(() {
      activeFaq = activeFaq == id ? -1 : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppConstants.customAppBar(
        context: context,
        title: 'FAQs',
        // Optionally, if you want a different back icon, you can pass:
        // backIconAsset: 'assets/your_custom_back.png',
      ), // 'b
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Questions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 15),
            Expanded(
              child:
                  isLoading
                      ? Stack(
                        children: [
                          // Semi-transparent dark overlay
                          Container(
                            color: Colors.black.withOpacity(
                              0.14,
                            ), // Dark overlay
                          ),

                          // Your original container with white tint and loader
                          Container(
                            color: Colors.white10,
                            child: Center(
                              child: Image.asset(
                                'assets/Bird_Full_Eye_Blinking.gif',
                                width: 100, // Adjust size as needed
                                height: 100,
                              ),
                            ),
                          ),
                        ],
                      )
                      : errorMessage.isNotEmpty
                      ? Center(
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      )
                      : faqList.isNotEmpty
                      ? ListView.builder(
                        itemCount: faqList.length,
                        itemBuilder: (context, index) {
                          final item = faqList[index];
                          final isActive = (activeFaq == item['id']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => toggleFaq(item['id']),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 15,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['question'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isActive
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      item['answer'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      )
                      : Center(
                        child: Text(
                          'No record found!',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
