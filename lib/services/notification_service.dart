import 'dart:async';
import 'dart:convert';

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();
  static const MethodChannel _badgeChannel = MethodChannel('app.badge');

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<User?>? _authSubscription;
  bool _initialized = false;
  bool _permissionsGranted = false;
  String? _cachedToken;
  String? _lastUserId;
  bool _notificationsAllowed = true;

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
          _notificationsAllowed = true;
          await clearBadge();
          return;
        }

        _lastUserId = user.uid;
        await _loadNotificationPreference(user.uid);
        if (!_notificationsAllowed) {
          return;
        }

        if (!_permissionsGranted) {
          await _requestPermissions();
        }
        if (!_permissionsGranted || !_notificationsAllowed) {
          return;
        }

        final token = await _messaging.getToken();
        if (_notificationsAllowed) {
          await _persistToken(token);
        }
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

  Future<void> _loadNotificationPreference(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).get();
      final data = snapshot.data();
      if (data == null) {
        _notificationsAllowed = true;
        return;
      }

      final prefMap = data['notificationPreferences'];
      if (prefMap is Map<String, dynamic>) {
        final pushEnabled = prefMap['pushEnabled'];
        if (pushEnabled is bool) {
          _notificationsAllowed = pushEnabled;
          return;
        }
      }

      final globalFlag = data['notificationsEnabled'];
      if (globalFlag is bool) {
        _notificationsAllowed = globalFlag;
        return;
      }
    } catch (_) {
      // Ignore lookup errors and fall back to defaults.
    }
    _notificationsAllowed = true;
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
    if (!_notificationsAllowed) {
      return;
    }
    await _persistToken(token);
  }

  Future<void> clearBadge() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isMacOS)) {
      return;
    }
    try {
      await _badgeChannel.invokeMethod('clearBadge');
    } catch (_) {
      // Ignore platform errors so badge clearing never crashes the app.
    }
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
    if (_lastUserId == null) {
      return;
    }

    await _removeTokenForUser(_lastUserId!, allowNoAuth: true);
    _cachedToken = null;
    _lastUserId = null;
  }

  Future<void> prepareForSignOut() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    await _removeTokenForUser(userId);
    _cachedToken = null;
    _lastUserId = null;
  }

  Future<void> signOutWithCleanup(FirebaseAuth auth) async {
    await prepareForSignOut();
    await auth.signOut();
  }

  Future<void> _removeTokenForUser(
    String userId, {
    bool allowNoAuth = false,
  }) async {
    final token = _cachedToken ?? await _messaging.getToken();
    if (token == null) {
      return;
    }

    if (!allowNoAuth) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        return;
      }
    }

    try {
      await _firestore.collection('users').doc(userId).update(
        {
          'fcmTokens': FieldValue.arrayRemove([token]),
        },
      );
    } catch (_) {
      // Ignore errors if the document or field does not exist.
    }
  }

  Future<bool> updateUserPreference(bool enabled) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _notificationsAllowed = enabled;
      return false;
    }

    _notificationsAllowed = enabled;
    if (!enabled) {
      await _removeTokenForUser(userId);
      _cachedToken = null;
      return true;
    }

    if (!_permissionsGranted) {
      await _requestPermissions();
    }
    if (!_permissionsGranted) {
      _notificationsAllowed = false;
      return false;
    }

    final token = await _messaging.getToken();
    await _persistToken(token);
    return true;
  }
}
