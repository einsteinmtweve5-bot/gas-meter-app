import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  debugPrint("Handling a background message: ${message.messageId}");
}


class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
      
  static DateTime? _lastNotificationTime;

  static Future<void> init() async {
    // Android initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Linux initialization
    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open App');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: initializationSettingsLinux,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
      },
    );

    // Create a high-priority channel for Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'leak_alerts', // id
        'Gas Leak Alerts', // title
        description: 'Critical alerts for gas leakage detection',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.createNotificationChannel(channel);
      
      // Request permission for Android 13+
      await androidImplementation?.requestNotificationsPermission();
    }
    
    // Setup FCM
    await _setupFCM();
  }

  static Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permissions (iOS/macOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
      
      // Get token
      String? token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen(_registerToken);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null) {
          showLeakAlert(); // Trigger the local alert for visibility
        }
      });
    }
  }

  static Future<void> _registerToken(String token) async {
    debugPrint('FCM Token: $token');
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('profiles').update({'fcm_token': token}).eq('id', userId);
        debugPrint('Token registered successfully');
      }
    } catch (e) {
      debugPrint('Error registering token: $e');
    }
  }

  static Future<void> showLeakAlert() async {
    // Throttle notifications to once per minute to avoid spamming
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMinutes < 1) {
      return;
    }
    _lastNotificationTime = now;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'leak_alerts',
      'Gas Leak Alerts',
      channelDescription: 'Critical alerts for gas leakage detection',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      color: const Color(0xFFFF0000),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500, 1000]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      0,
      '🚨 CRITICAL: GAS LEAK DETECTED',
      'Gas leak has been detected! The valve has been automatically closed.',
      platformChannelSpecifics,
      payload: 'leak_alert',
    );
  }
  
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
