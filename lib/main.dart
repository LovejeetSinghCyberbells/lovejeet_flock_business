import 'package:flock/DeleteAccountScreen.dart';
import 'package:flock/ForgotPasswordScreen.dart';
import 'package:flock/HomeScreen.dart';
import 'package:flock/app_colors.dart';
import 'package:flock/changePassword.dart';
import 'package:flock/editProfile.dart';
import 'package:flock/faq.dart';
import 'package:flock/feedback.dart';
import 'package:flock/history.dart';
import 'package:flock/offers.dart';
import 'package:flock/openHours.dart';
import 'package:flock/registration_screen.dart';
import 'package:flock/staffManagement.dart';
import 'package:flock/tutorial.dart';
import 'package:flock/venue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';
import 'login_screen.dart';
import 'checkIns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:flock/services/fcm_service.dart';

import 'screens/logs_viewer_screen.dart';

// Define light and dark themes
class AppThemes {
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color.fromRGBO(255, 130, 16, 1),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.black,
      selectionColor: AppColors.primary.withOpacity(0.2),
      selectionHandleColor: AppColors.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.black54),
      floatingLabelStyle: TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black54, width: 2.0),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.black87),
    ),
    iconTheme: IconThemeData(color: Colors.black87),
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primary.withOpacity(0.7),
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.black87,
      onSurface: Colors.black87,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primary,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: Colors.white,
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color.fromRGBO(255, 130, 16, 1),
    scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Professional dark black
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1A1A1A),
      foregroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.white,
      selectionColor: AppColors.primary.withOpacity(0.3),
      selectionHandleColor: AppColors.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white70),
      floatingLabelStyle: TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: const Color(0xFF2C2C2C)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2.0),
      ),
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white70),
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: Colors.white),
    ),
    iconTheme: IconThemeData(color: Colors.white),
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primary.withOpacity(0.7),
      surface: const Color.fromARGB(255, 20, 20, 20),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primary,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: Colors.white,
    ),
  );
}

// Notification model to store notification data
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? screen;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.screen,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'screen': screen,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        screen: json['screen'],
        timestamp: DateTime.parse(json['timestamp']),
        isRead: json['isRead'],
      );
}

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Notification Message : $message");
  // Store notification locally
  await _storeNotification(message);
}

// Store notification in SharedPreferences
Future<void> _storeNotification(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  final notification = NotificationModel(
    id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title:
        message.notification?.title ??
        message.data['title'] ??
        'New Notification',
    body:
        message.notification?.body ??
        message.data['body'] ??
        'No details available',
    screen: message.data['screen'],
    timestamp: DateTime.now(),
  );

  List<String> notifications = prefs.getStringList('notifications') ?? [];
  notifications.add(jsonEncode(notification.toJson()));
  await prefs.setStringList('notifications', notifications);
  print('Stored notification: ${notification.toJson()}');
}

Future<String?> getFCMToken() async {
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // For iOS, ensure APNS token is available first
    if (Platform.isIOS) {
      print('iOS device detected, waiting for APNS token...');
      int maxRetries = 5;
      int currentRetry = 0;
      String? apnsToken;

      while (currentRetry < maxRetries) {
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null) {
          print('APNS Token obtained: $apnsToken');
          break;
        }
        print(
          'APNS Token not available, attempt ${currentRetry + 1} of $maxRetries',
        );
        await Future.delayed(Duration(seconds: 2));
        currentRetry++;
      }

      if (apnsToken == null) {
        print('Failed to get APNS token after $maxRetries attempts');
        return null;
      }
    }

    // Now try to get FCM token
    print('Requesting FCM token...');
    int maxTokenRetries = 3;
    int currentTokenRetry = 0;
    String? fcmToken;

    while (currentTokenRetry < maxTokenRetries) {
      try {
        fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          print('FCM Token obtained: $fcmToken');
          return fcmToken;
        }
        print(
          'FCM Token not available, attempt ${currentTokenRetry + 1} of $maxTokenRetries',
        );
        await Future.delayed(Duration(seconds: 2));
      } catch (e) {
        print(
          'Error getting FCM token on attempt ${currentTokenRetry + 1}: $e',
        );
      }
      currentTokenRetry++;
    }

    print('Failed to get FCM token after $maxTokenRetries attempts');
    return null;
  } catch (e) {
    print('Error in getFCMToken: $e');
    return null;
  }
}

// Background task names
const backgroundRefreshTask = "com.flock.business.app.refresh";
const backgroundProcessingTask = "com.flock.business.app.processing";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case backgroundRefreshTask:
        // Implement your background refresh logic here
        return true;
      case backgroundProcessingTask:
        // Implement your background processing logic here
        return true;
      default:
        return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterBranchSdk.init();

  if (Platform.isIOS) {
    // Initialize Workmanager for background tasks
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to false for release mode
    );

    // Register periodic background tasks
    await Workmanager().registerPeriodicTask(
      "refresh",
      backgroundRefreshTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(seconds: 60), // Add initial delay
    );

    await Workmanager().registerPeriodicTask(
      "processing",
      backgroundProcessingTask,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 5), // Add initial delay
    );
  }

  try {
    // Initialize Firebase with retry logic
    bool firebaseInitialized = false;
    int retryCount = 0;
    const maxRetries = 3;

    while (!firebaseInitialized && retryCount < maxRetries) {
      try {
        await Firebase.initializeApp();
        firebaseInitialized = true;
        print("[Firebase] Firebase has been initialized successfully.");
        developer.log("[Firebase] Firebase has been initialized successfully.");

        // Set up FCM background message handler
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Request permissions for iOS
        if (Platform.isIOS) {
          developer.log("[Firebase] Requesting iOS notification permissions");
          final settings = await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          developer.log(
            "[Firebase] iOS notification settings: ${settings.authorizationStatus}",
          );
          print(
            "[Firebase] iOS notification settings: ${settings.authorizationStatus}",
          );
        } else if (Platform.isAndroid) {
          // ✅ Android 13+ requires runtime notification permission
          developer.log(
            "[Firebase] Requesting Android notification permissions",
          );
          final status = await Permission.notification.status;

          if (status.isDenied || status.isRestricted) {
            final result = await Permission.notification.request();
            developer.log(
              "[Firebase] Android notification permission: $result",
            );
            print("[Firebase] Android notification permission: $result");
          } else {
            developer.log(
              "[Firebase] Android notification permission already granted",
            );
            print("[Firebase] Android notification permission already granted");
          }
        }

        // Enable FCM auto-init
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
      } catch (e) {
        retryCount++;
        developer.log(
          "[Firebase] Initialization attempt $retryCount failed: $e",
        );
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }

    if (!firebaseInitialized) {
      developer.log(
        "[Firebase] Failed to initialize Firebase after $maxRetries attempts",
      );
    }
  } catch (e) {
    developer.log("[Firebase] Fatal error during Firebase initialization: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navigatorKey = GlobalKey<NavigatorState>();

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Flock Login',
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside
            FocusScope.of(context).unfocus();
          },
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(1.0),
            ), // Prevent font scaling
            child: child!,
          ),
        );
      },
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: ThemeMode.system, // Automatically switch based on device
      home: const LoadingScreen(),
      routes: {
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/home': (context) => TabDashboard(),
        '/EditProfile': (context) => const EditProfileScreen(),
        '/staffManage': (context) => const StaffManagementScreen(),
        '/changePassword': (context) => const ChangePasswordScreen(),
        '/openHours': (context) => const OpenHoursScreen(),
        '/feedback': (context) => const ReportScreen(),
        '/DeleteAccount': (context) => const DeleteAccountScreen(),
        '/tutorials': (context) => const TutorialsScreen(),
        '/login': (context) => const LoginScreen(),
        '/tab_checkin': (context) => const CheckInsScreen(),
        '/register': (context) => const RegisterScreen(),
        '/tab_egg': (context) => const TabEggScreen(),
        '/faq': (context) => FaqScreen(),
        '/offers': (context) => const OffersScreen(),
        '/HistoryScreen': (context) => const HistoryScreen(),
        '/history': (context) => const HistoryScreen(),
        '/dashboard': (context) => TabDashboard(),
      },
    );
  }
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  int _unreadNotifications = 0;
  List<NotificationModel> _notifications = [];
  final _platform = const MethodChannel('com.flockbusiness/notifications');

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _loadNotifications();
    _checkLoginStatus();
  }

  Future<void> _setupFCM() async {
    try {
      // Set up method channel handler
      _platform.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onFCMTokenReceived':
            print(
              '[FCM Debug] Received FCM token from native: ${call.arguments['token']}',
            );
            final token = call.arguments['token'] as String;
            final prefs = await SharedPreferences.getInstance();
            final accessToken = prefs.getString('access_token');
            if (accessToken != null) {
              await FCMService.updateToken(accessToken);
            }
            break;
          case 'onFCMTokenRefreshed':
            print(
              '[FCM Debug] Received refreshed FCM token from native: ${call.arguments['token']}',
            );
            final token = call.arguments['token'] as String;
            final prefs = await SharedPreferences.getInstance();
            final accessToken = prefs.getString('access_token');
            if (accessToken != null) {
              await FCMService.updateToken(accessToken);
            }
            break;
        }
      });

      // Request notification permissions for iOS
      if (Platform.isIOS) {
        print(
          '[FCM Debug] iOS platform detected, requesting notification permissions...',
        );
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        print(
          '[FCM Debug] User granted permission: ${settings.authorizationStatus}',
        );
      }

      // Get access token and set up FCM
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken != null) {
        await FCMService.setupFCMListeners(accessToken);
        // Try to update token if needed
        await FCMService.updateToken(accessToken);
      }
    } catch (e, stackTrace) {
      print('[FCM Debug] Error setting up FCM: $e');
      print('[FCM Debug] Stack trace: $stackTrace');
    }
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationStrings = prefs.getStringList('notifications') ?? [];
    final notifications =
        notificationStrings
            .map((string) => NotificationModel.fromJson(jsonDecode(string)))
            .toList();
    setState(() {
      _notifications = notifications;
      _unreadNotifications = notifications.where((n) => !n.isRead).length;
    });
    print(
      'Loaded ${_notifications.length} notifications, $_unreadNotifications unread',
    );
  }

  Future<void> _registerForRemoteNotifications() async {
    if (Platform.isIOS) {
      print('Requesting remote notification registration on iOS...');

      // Get the current notification settings
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      print('Current notification settings:');
      print('Authorization status: ${settings.authorizationStatus}');
      print('Alert permission: ${settings.alert}');
      print('Badge permission: ${settings.badge}');
      print('Sound permission: ${settings.sound}');

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
          settings.authorizationStatus == AuthorizationStatus.denied) {
        print('Requesting notification permissions...');
        final NotificationSettings newSettings = await FirebaseMessaging
            .instance
            .requestPermission(
              alert: true,
              badge: true,
              sound: true,
              criticalAlert: true,
              provisional: false,
            );
        print('New authorization status: ${newSettings.authorizationStatus}');
      }
    }
  }

  Future<void> _markNotificationAsRead(String? messageId) async {
    if (messageId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationStrings = prefs.getStringList('notifications') ?? [];
    final notifications =
        notificationStrings
            .map((string) => NotificationModel.fromJson(jsonDecode(string)))
            .toList();

    final updatedNotifications =
        notifications.map((n) {
          if (n.id == messageId) {
            return NotificationModel(
              id: n.id,
              title: n.title,
              body: n.body,
              screen: n.screen,
              timestamp: n.timestamp,
              isRead: true,
            );
          }
          return n;
        }).toList();

    await prefs.setStringList(
      'notifications',
      updatedNotifications.map((n) => jsonEncode(n.toJson())).toList(),
    );

    setState(() {
      _notifications = updatedNotifications;
      _unreadNotifications =
          updatedNotifications.where((n) => !n.isRead).length;
    });
    print(
      'Marked notification $messageId as read, $_unreadNotifications unread remaining',
    );
  }

  void _handleMessageNavigation(RemoteMessage message) {
    // Only navigate if user is logged in
    final screen = message.data['screen'];
    if (screen == 'checkin' || screen == 'offers') {
      SharedPreferences.getInstance().then((prefs) {
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        if (isLoggedIn && mounted) {
          Navigator.pushNamed(
            context,
            screen == 'checkin' ? '/tab_checkin' : '/offers',
          );
        }
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    // Wait for notifications to load
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final token = prefs.getString('access_token');

    // Retry sending stored FCM token if available
    final fcmToken = prefs.getString('fcm_token');
    if (fcmToken != null && isLoggedIn && token != null) {
      await FCMService.updateToken(token);
    }

    if (mounted) {
      if (isLoggedIn && token != null && token.isNotEmpty) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flock Business')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Flock Business',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            // ... existing drawer items ...
            if (kReleaseMode) // Only show in release/TestFlight mode
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('View Logs'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LogsViewerScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
