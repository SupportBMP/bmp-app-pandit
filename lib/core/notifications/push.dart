import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api.dart';
import '../router/routes.dart';
import '../storage/prefs.dart';
import 'firebase_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Notification messages are drawn by the OS; taps are handled by
  // getInitialMessage / onMessageOpenedApp.
  await Firebase.initializeApp(options: FirebaseConfig.current);
}

/// FCM push: permission, token registration with the backend, foreground
/// display, and tap routing by `data.route` (+ JSON `data.params`), the
/// same payload contract as the RN app's notificationHandler.js.
class Push {
  Push._();

  static final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'default',
    'Notifications',
    description: 'Bookings, e-puja and account updates',
    importance: Importance.high,
  );

  /// Set by the app: navigates to a path with optional `extra`.
  static void Function(String path, Object? extra)? navigate;
  static bool _ready = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(options: FirebaseConfig.current);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      await _local.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notification'), iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) _route(jsonDecode(r.payload!) as Map<String, dynamic>);
        },
      );
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);

      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _route(m.data));
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => registerToken());
      _ready = true;
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// Ask for permission (Android 13+ / iOS) — called once the shell is up.
  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }

  /// Notification that launched the app from a terminated state.
  static Future<void> handleInitialMessage() async {
    if (!_ready) return;
    final m = await FirebaseMessaging.instance.getInitialMessage();
    if (m != null) _route(m.data);
  }

  /// Sends this device's FCM token to `/api/fcm-token/save` (the RN app had
  /// this disabled, so production devices were never registered).
  static Future<void> registerToken() async {
    if (!_ready || Prefs.token == null) return;
    try {
      if (Platform.isIOS) await FirebaseMessaging.instance.getAPNSToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await Api.saveFcmToken({'token': token});
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    if (Platform.isIOS) return; // iOS presents it via the foreground options above.
    await _local.show(
      id: m.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF8A1C23),
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

  static void _route(Map<String, dynamic> data) {
    final route = data['route'];
    if (route is! String || route.isEmpty) return;
    final path = legacyRouteNames[route] ?? (route.startsWith('/') ? route : null);
    if (path == null) return;
    Object? params = data['params'];
    if (params is String && params.isNotEmpty) {
      try {
        params = jsonDecode(params);
      } catch (_) {}
    }
    navigate?.call(path, params);
  }
}
