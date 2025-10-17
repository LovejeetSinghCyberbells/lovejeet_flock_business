import 'dart:io';

import 'package:flock/videoPlayer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TutorialsScreen extends StatefulWidget {
  const TutorialsScreen({super.key});

  @override
  State<TutorialsScreen> createState() => _TutorialsScreenState();
}

class _TutorialsScreenState extends State<TutorialsScreen> {
  List<dynamic> tutorials = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTutorials();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _fetchTutorials() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          errorMessage = 'Please login to view tutorials';
        });
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://api.getflock.io/api/vendor/tutorials'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            tutorials = List<dynamic>.from(data['data']);
          });
          return;
        }
        throw Exception(data['message'] ?? 'Invalid data format');
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('access_token');
        setState(() {
          errorMessage = 'Session expired. Please login again.';
        });
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
        return;
      } else {
        throw Exception('Failed to load tutorials (${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTutorialCard(Map<String, dynamic> tutorial) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tutorial['name'] ?? 'No Title',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tutorial['description'] ?? 'No description',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.play_circle_outline,
                    size: 40,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () {
                    _playTutorial(tutorial['url'] ?? '');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playTutorial(String rawUrl) {
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 25),
          content: const Text('No video available'),
          backgroundColor: Theme.of(context).snackBarTheme.backgroundColor,
          // contentTextStyle: Theme.of(context).snackBarTheme.contentTextStyle,
        ),
      );
      return;
    }

    String videoUrl;
    if (rawUrl.contains('https://')) {
      final split = rawUrl.split('https://');
      videoUrl = 'https://${split.last}';
    } else {
      videoUrl = rawUrl;
    }

    debugPrint('Final video URL: $videoUrl');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/back_updated.png',
                      height: 40,
                      width: 34,
                      // fit: BoxFit.contain,
                      // color: Theme.of(context).colorScheme.primary, // Orange tint
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Tutorials",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  isLoading
                      ? Stack(
                        children: [
                          Container(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.14),
                          ),
                          Container(
                            color: Colors.transparent,
                            child: Center(
                              child: Image.asset(
                                'assets/Bird_Full_Eye_Blinking.gif',
                                width: 100,
                                height: 100,
                              ),
                            ),
                          ),
                        ],
                      )
                      : errorMessage.isNotEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              errorMessage,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.redAccent
                                        : Colors.red,
                              ),
                            ),
                            if (!errorMessage.contains('login'))
                              const SizedBox(height: 16),
                            if (!errorMessage.contains('login'))
                              ElevatedButton(
                                onPressed: _fetchTutorials,
                                style:
                                    Theme.of(context).elevatedButtonTheme.style,
                                child: const Text('Retry'),
                              ),
                          ],
                        ),
                      )
                      : tutorials.isEmpty
                      ? Center(
                        child: Text(
                          'No tutorials available',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                      : ListView.builder(
                        itemCount: tutorials.length,
                        itemBuilder: (context, index) {
                          final tutorial =
                              tutorials[index] as Map<String, dynamic>;
                          return _buildTutorialCard(tutorial);
                        },
                      ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse('https://getflock.io/business/');
                    debugPrint('Attempting to launch URL: $url');
                    try {
                      final launched = await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                      debugPrint('Launch result: $launched');
                      if (!launched) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              padding: EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 20,
                                bottom: 25,
                              ),
                              content: const Text('Could not open the link'),
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).snackBarTheme.backgroundColor,
                              // contentTextStyle: Theme.of(context).snackBarTheme.contentTextStyle,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('Error launching URL: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 20,
                              bottom: 25,
                            ),
                            content: Text('Error launching URL: $e'),
                            backgroundColor:
                                Theme.of(context).snackBarTheme.backgroundColor,
                            // contentTextStyle: Theme.of(context).snackBarTheme.contentTextStyle,
                          ),
                        );
                      }
                    }
                  },
                  style: Theme.of(context).elevatedButtonTheme.style,
                  child: const Text(
                    "Learn More",
                    style: TextStyle(fontSize: 16),
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
