import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;
  bool _permissionsGranted = false;
  String? _cachedToken;
  String? _lastUserId;

  static const AndroidNotificationChannel _defaultAndroidChannel =
      AndroidNotificationChannel(
    'wishlink_default_channel',
    'WishLink Alerts',
    description: 'General notifications triggered by WishLink activity.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _configureLocalNotifications();
    await _requestPermissions();
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) async {
        if (user == null) {
          await _removeTokenFromPreviousUser();
          return;
        }

        _lastUserId = user.uid;
        if (!_permissionsGranted) {
          await _requestPermissions();
        }
        if (!_permissionsGranted) {
          return;
        }

        final token = await _messaging.getToken();
        await _persistToken(token);
      },
    );
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
  }

  Future<void> _configureLocalNotifications() async {
    if (kIsWeb) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotificationsPlugin.initialize(initializationSettings);

    final androidImplementation =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(
      _defaultAndroidChannel,
    );
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      _permissionsGranted = true;
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _permissionsGranted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!_permissionsGranted) {
      return;
    }

    final iosImplementation =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidImplementation =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kIsWeb) return;

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;

    if (title == null && body == null) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _defaultAndroidChannel.id,
      _defaultAndroidChannel.name,
      channelDescription: _defaultAndroidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'WishLink',
      icon: notification?.android?.smallIcon ?? '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentBadge: true,
      presentSound: true,
      presentAlert: true,
    );

    await _localNotificationsPlugin.show(
      notification?.hashCode ?? message.hashCode,
      title ?? 'WishLink',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _handleTokenRefresh(String token) async {
    _cachedToken = token;
    await _persistToken(token);
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedToken = token;
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
          'notificationsEnabled': true,
        },
        SetOptions(merge: true),
      );

      _cachedToken = token;
      _lastUserId = user.uid;
    } catch (_) {
      // Ignore Firestore write errors for now. Caller can retry later.
    }
  }

  Future<void> _removeTokenFromPreviousUser() async {
    if (_cachedToken == null || _lastUserId == null) {
      return;
    }

    try {
      await _firestore.collection('users').doc(_lastUserId!).update(
        {
          'fcmTokens': FieldValue.arrayRemove([_cachedToken]),
        },
      );
    } catch (_) {
      // Ignore cleanup errors if the document was already removed.
    } finally {
      _lastUserId = null;
    }
  }
}
