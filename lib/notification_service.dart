import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:food_delivery_platform/database_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Foreground message title: ${message.notification?.title}');
      debugPrint('Foreground message body: ${message.notification?.body}');
      debugPrint('Foreground message data: ${message.data}');

      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Opened from notification with data: ${message.data}');
    });

    _isInitialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'order_updates_channel',
      'Order Updates',
      channelDescription: 'Notifications for order updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  Future<void> saveTokenForUser(String userId) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    await DatabaseService().updateUser(
      userId: userId,
      data: {
        'fcmToken': token,
        'fcmTokenUpdatedAt': firestore.FieldValue.serverTimestamp(),
      },
    );

    _messaging.onTokenRefresh.listen((newToken) async {
      await DatabaseService().updateUser(
        userId: userId,
        data: {
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': firestore.FieldValue.serverTimestamp(),
        },
      );
    });
  }
}
