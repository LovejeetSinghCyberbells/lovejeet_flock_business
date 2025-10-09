import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';

// Helper function to extract the content inside the <body> tag
String extractBodyContent(String html) {
  final bodyRegExp = RegExp(r'<body[^>]*>(.*?)<\/body>', dotAll: true);
  final match = bodyRegExp.firstMatch(html);
  return match != null ? match.group(1)! : html;
}

class TermsAndConditionsPage extends StatefulWidget {
  const TermsAndConditionsPage({super.key});

  @override
  _TermsAndConditionsPageState createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  String termsHtml = "";
  bool _isLoading = true;

  // Fetch the Terms and Conditions from the API
  Future<void> _fetchTermsAndConditions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      const String termsUrl = 'https://api.getflock.io/api/vendor/terms';
      final response = await http.get(Uri.parse(termsUrl));

      debugPrint("API Response Status: ${response.statusCode}");
      debugPrint("API Response Body: ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          termsHtml = response.body;
          _isLoading = false;
        });
      } else {
        _showError(
          "Failed to load Terms and Conditions. Status: ${response.statusCode}",
        );
      }
    } catch (error) {
      debugPrint("Error fetching Terms and Conditions: $error");
      _showError("Error fetching Terms and Conditions: $error");
    }
  }

  // Show error dialog
  void _showError(String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              if (message.contains("Unauthorized"))
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Log In'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTermsAndConditions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Terms and Conditions"),
        backgroundColor: const Color.fromRGBO(255, 130, 16, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? Stack(
                  children: [
                    // Semi-transparent dark overlay
                    Container(
                      color: Colors.black.withOpacity(0.14), // Dark overlay
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
                : termsHtml.isEmpty
                ? const Center(
                  child: Text("No Terms and Conditions available."),
                )
                : SingleChildScrollView(
                  child: Html(
                    data: extractBodyContent(termsHtml),
                    style: {
                      "body": Style(
                        fontFamily: 'Arial',
                        fontSize: FontSize(16),
                        lineHeight: LineHeight(1.6),
                        color: Colors.black,
                      ),
                      "h1": Style(
                        fontSize: FontSize(22),
                        fontWeight: FontWeight.bold,
                      ),
                      "h2": Style(
                        fontSize: FontSize(20),
                        fontWeight: FontWeight.bold,
                      ),
                      "h3": Style(
                        fontSize: FontSize(18),
                        fontWeight: FontWeight.bold,
                      ),
                      "ul": Style(margin: Margins.all(8)),
                      "li": Style(margin: Margins.only(bottom: 6)),
                      "p": Style(margin: Margins.only(bottom: 10)),
                    },
                  ),
                ),
      ),
    );
  }
}
