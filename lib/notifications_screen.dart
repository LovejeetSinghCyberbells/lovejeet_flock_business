import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart'; // Import for NotificationModel
import 'app_colors.dart'; // For AppColors.primary

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationStrings = prefs.getStringList('notifications') ?? [];
    final notifications = notificationStrings
        .map((string) => NotificationModel.fromJson(jsonDecode(string)))
        .toList();
    setState(() {
      _notifications = notifications;
      _unreadNotifications = notifications.where((n) => !n.isRead).length;
    });
    print('Loaded ${_notifications.length} notifications, $_unreadNotifications unread');
  }

  Future<void> _markNotificationAsRead(String? messageId) async {
    if (messageId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final notificationStrings = prefs.getStringList('notifications') ?? [];
    final notifications = notificationStrings
        .map((string) => NotificationModel.fromJson(jsonDecode(string)))
        .toList();

    final updatedNotifications = notifications.map((n) {
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
      _unreadNotifications = updatedNotifications.where((n) => !n.isRead).length;
    });
    print('Marked notification $messageId as read, $_unreadNotifications unread remaining');
  }

  void _handleNotificationTap(NotificationModel notification) {
    _markNotificationAsRead(notification.id);
    final screen = notification.screen;
    if (screen == 'checkin' || screen == 'offers') {
      SharedPreferences.getInstance().then((prefs) {
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        if (isLoggedIn && mounted) {
          Navigator.pushNamed(context, screen == 'checkin' ? '/tab_checkin' : '/offers');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _notifications.isEmpty
          ? const Center(child: Text('No notifications available'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(notification.body),
                    trailing: notification.isRead
                        ? null
                        : const Icon(Icons.circle, color: Colors.red, size: 10),
                    onTap: () => _handleNotificationTap(notification),
                  ),
                );
              },
            ),
    );
  }
}