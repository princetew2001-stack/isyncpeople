import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    
    // Create notification channels
    await _createNotificationChannels();
  }
  
  static Future<void> _createNotificationChannels() async {
    // Attendance channel
    const AndroidNotificationChannel attendanceChannel = AndroidNotificationChannel(
      'attendance_channel',
      'Attendance Notifications',
      description: 'Notifications for attendance tracking',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    // Visitor notifications channel
    const AndroidNotificationChannel visitorChannel = AndroidNotificationChannel(
      'visitor_notifications',
      'Visitor Notifications',
      description: 'Notifications for visitor arrivals',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(attendanceChannel);
      await androidPlugin.createNotificationChannel(visitorChannel);
    }
  }

  static Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showClockInNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'attendance_channel',
        'Attendance Notifications',
        channelDescription: 'Notifications for attendance tracking',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD2691E),
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        1,
        'Clocked In Successfully! 🎯',
        'Have a productive day!',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Error showing clock-in notification: $e');
      // Don't rethrow - notification failure shouldn't break the app
    }
  }

  static Future<void> showClockOutNotification() async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'attendance_channel',
        'Attendance Notifications',
        channelDescription: 'Notifications for attendance tracking',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD2691E),
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        2,
        'Clocked Out Successfully! 🌟',
        'Enjoy your well deserved rest!',
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Error showing clock-out notification: $e');
      // Don't rethrow - notification failure shouldn't break the app
    }
  }

  static Future<void> showMotivationalNotification(String title, String message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'attendance_channel',
        'Attendance Notifications',
        channelDescription: 'Notifications for attendance tracking',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFD2691E),
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        message,
        platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('❌ Error showing motivational notification: $e');
      // Don't rethrow - notification failure shouldn't break the app
    }
  }
}