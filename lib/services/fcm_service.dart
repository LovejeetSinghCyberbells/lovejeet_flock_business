import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'logger_service.dart';

class FCMService {
  static const String _deviceUpdateUrl =
      'https://api.getflock.io/api/vendor/devices/update';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _tokenUpdateStatusKey = 'token_update_status';

  static Future<String?> getFCMToken() async {
    try {
      await LoggerService.log(
        'FCM Service',
        'Starting FCM token retrieval',
        LogType.token,
      );

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // For iOS, ensure APNS token is available first
      if (Platform.isIOS) {
        await LoggerService.log(
          'FCM Service',
          'iOS device detected, waiting for APNS token',
          LogType.token,
        );

        int maxRetries = 5;
        int currentRetry = 0;
        String? apnsToken;

        while (currentRetry < maxRetries) {
          apnsToken = await messaging.getAPNSToken();
          if (apnsToken != null) {
            await LoggerService.log(
              'FCM Service',
              'APNS Token obtained',
              LogType.token,
              data: {'token': apnsToken},
            );
            break;
          }
          await LoggerService.log(
            'FCM Service',
            'APNS Token not available, retrying...',
            LogType.token,
            data: {'attempt': currentRetry + 1, 'maxRetries': maxRetries},
          );
          await Future.delayed(Duration(seconds: 3));
          currentRetry++;
        }

        if (apnsToken == null) {
          await LoggerService.log(
            'FCM Service',
            'Failed to get APNS token after max retries',
            LogType.error,
          );
          return null;
        }
      }

      // Get FCM token with retry logic
      int maxTokenRetries = 3;
      int currentTokenRetry = 0;
      String? fcmToken;

      while (currentTokenRetry < maxTokenRetries) {
        try {
          fcmToken = await messaging.getToken();
          if (fcmToken != null) {
            await LoggerService.log(
              'FCM Service',
              'FCM Token obtained',
              LogType.token,
              data: {'token': fcmToken},
            );
            // Store the token
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_fcmTokenKey, fcmToken);
            return fcmToken;
          }
          await LoggerService.log(
            'FCM Service',
            'FCM Token not available, retrying...',
            LogType.token,
            data: {
              'attempt': currentTokenRetry + 1,
              'maxRetries': maxTokenRetries,
            },
          );
          await Future.delayed(Duration(seconds: 3));
        } catch (e) {
          await LoggerService.log(
            'FCM Service',
            'Error getting FCM token',
            LogType.error,
            data: {'error': e.toString(), 'attempt': currentTokenRetry + 1},
          );
          currentTokenRetry++;
          await Future.delayed(Duration(seconds: 3));
        }
        currentTokenRetry++;
      }

      await LoggerService.log(
        'FCM Service',
        'Failed to get FCM token after max retries',
        LogType.error,
      );
      return null;
    } catch (e) {
      await LoggerService.log(
        'FCM Service',
        'Error in getFCMToken',
        LogType.error,
        data: {'error': e.toString()},
      );
      return null;
    }
  }

  static Future<bool> updateToken(String accessToken) async {
    try {
      await LoggerService.log(
        'FCM Service',
        'Starting token update process',
        LogType.token,
      );

      // Get the current FCM token
      String? fcmToken = await getFCMToken();
      if (fcmToken == null) {
        await LoggerService.log(
          'FCM Service',
          'No FCM token available to update',
          LogType.error,
        );
        return false;
      }

      // Check if this token was already successfully updated
      final prefs = await SharedPreferences.getInstance();
      final lastUpdatedToken = prefs.getString(_tokenUpdateStatusKey);
      if (lastUpdatedToken == fcmToken) {
        await LoggerService.log(
          'FCM Service',
          'Token already updated successfully',
          LogType.token,
        );
        return true;
      }

      // Send token to backend
      final requestBody = {
        'token': fcmToken,
        'type': Platform.isIOS ? 'ios' : 'android',
      };

      await LoggerService.log(
        'FCM Service',
        'Sending token to backend',
        LogType.api,
        data: {'url': _deviceUpdateUrl, 'requestBody': requestBody},
      );

      final response = await http.post(
        Uri.parse(_deviceUpdateUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      await LoggerService.log(
        'FCM Service',
        'Received response from backend',
        LogType.api,
        data: {'statusCode': response.statusCode, 'body': response.body},
      );

      if (response.statusCode == 200) {
        await LoggerService.log(
          'FCM Service',
          'Device token updated successfully',
          LogType.token,
        );
        // Mark this token as successfully updated
        await prefs.setString(_tokenUpdateStatusKey, fcmToken);
        return true;
      } else {
        final responseData = jsonDecode(response.body);
        await LoggerService.log(
          'FCM Service',
          'Failed to update device token',
          LogType.error,
          data: {
            'statusCode': response.statusCode,
            'error': responseData['message'] ?? 'Unknown error',
          },
        );
        return false;
      }
    } catch (error, stackTrace) {
      await LoggerService.log(
        'FCM Service',
        'Error updating device token',
        LogType.error,
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      return false;
    }
  }

  static Future<void> setupFCMListeners(String? accessToken) async {
    if (accessToken == null) return;

    try {
      // Configure notification settings for iOS
      if (Platform.isIOS) {
        await LoggerService.log(
          'FCM Service',
          'Configuring iOS notification settings',
          LogType.notification,
        );

        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );

        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        await LoggerService.log(
          'FCM Service',
          'iOS notification settings configured',
          LogType.notification,
          data: {
            'authorizationStatus': settings.authorizationStatus.toString(),
            'alert': settings.alert,
            'badge': settings.badge,
            'sound': settings.sound,
          },
        );
      } else if (Platform.isAndroid) {
        await LoggerService.log(
          'FCM Service',
          'Requesting Android notification permission',
          LogType.notification,
        );

        final status = await Permission.notification.status;
        if (!status.isGranted) {
          final result = await Permission.notification.request();
          print("Result of Permissions: $result");
          await LoggerService.log(
            'FCM Service',
            'Android notification permission result: $result',
            LogType.notification,
          );
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        await LoggerService.log(
          'FCM Service',
          'Received foreground message',
          LogType.notification,
          data: {
            'messageId': message.messageId,
            'title': message.notification?.title,
            'body': message.notification?.body,
            'data': message.data,
          },
        );
        final notification = message.notification;
        print("Notification : ${notification?.title} ${notification?.body} ");
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const InitializationSettings initializationSettings =
            InitializationSettings(android: initializationSettingsAndroid);

        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
        );
        // Handle incoming messages when app is in foreground
        if (notification != null) {
          print("Notification12 : $notification");

          const AndroidNotificationDetails androidDetails =
              AndroidNotificationDetails(
                'default_channel_id',
                'Default Channel',
                channelDescription: 'Used for important notifications',
                importance: Importance.high,
                priority: Priority.high,
                playSound: true,
                icon: '@drawable/app_logo', // ✅ from res/drawable
                largeIcon: DrawableResourceAndroidBitmap('app_logo'),
              );

          const NotificationDetails platformDetails = NotificationDetails(
            android: androidDetails,
          );

          await flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title ?? 'No Title',
            notification.body ?? 'No Body',
            platformDetails,
          );
        }
      });

      // Handle notification open events when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((
        RemoteMessage message,
      ) async {
        await LoggerService.log(
          'FCM Service',
          'Notification opened app from background',
          LogType.notification,
          data: {
            'messageId': message.messageId,
            'title': message.notification?.title,
            'body': message.notification?.body,
            'data': message.data,
          },
        );
      });

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await LoggerService.log(
          'FCM Service',
          'FCM Token refreshed',
          LogType.token,
          data: {'newToken': newToken},
        );

        // Store the new token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_fcmTokenKey, newToken);
        // Update the backend
        await updateToken(accessToken);
      });
    } catch (error, stackTrace) {
      await LoggerService.log(
        'FCM Service',
        'Error in setupFCMListeners',
        LogType.error,
        data: {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
  }
}
