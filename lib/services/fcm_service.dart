import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../config/fcm_config.dart';

// ── Background message handler (top-level — required by FCM) ─────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  debugPrint('📬 FCM background: ${message.notification?.title}');
}

/// Manages FCM token lifecycle and sends push notifications via the
/// FCM HTTP v1 API using a service account JSON for OAuth2 authentication.
///
/// OAuth2 access tokens are cached and automatically refreshed before they
/// expire, so only the first push per session makes a token-exchange call.
class FcmService {
  FcmService._();
  static final FcmService _i = FcmService._();
  factory FcmService() => _i;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  FirebaseFirestore? get _db =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  // ── OAuth2 token cache ────────────────────────────────────────────────────
  String? _cachedAccessToken;
  DateTime? _tokenExpiresAt;

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Call once from [main()] after Firebase.initializeApp().
  Future<void> init() async {
    if (Firebase.apps.isEmpty) return;

    // Register the background/terminated message handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request OS-level notification permission.
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 FCM permission: ${settings.authorizationStatus.name}');

    // iOS: show heads-up banners even when the app is in foreground.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message listener (Android doesn't auto-show banners).
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Tap handler — app was in background when the notification arrived.
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Tap handler — app was terminated.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onNotificationTap(initial);

    debugPrint('✅ FcmService initialised (v1 API)');
  }

  // ── Token management ───────────────────────────────────────────────────────

  /// Gets the device FCM token and saves it under `users/{uid}.fcm_token`.
  Future<void> saveTokenForUser(String uid) async {
    if (_db == null || uid.isEmpty) return;
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      await _db!.collection('users').doc(uid).update({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FCM token saved for $uid');

      // Keep token fresh if FCM rotates it.
      _fcm.onTokenRefresh.listen((newToken) async {
        await _db!.collection('users').doc(uid).update({
          'fcm_token': newToken,
          'fcm_token_updated_at': FieldValue.serverTimestamp(),
        });
        debugPrint('🔄 FCM token refreshed for $uid');
      });
    } catch (e) {
      debugPrint('⚠️ FcmService.saveTokenForUser: $e');
    }
  }

  /// Removes the FCM token from Firestore on logout so stale tokens
  /// no longer receive notifications for the signed-out account.
  Future<void> clearTokenForUser(String uid) async {
    if (_db == null || uid.isEmpty) return;
    try {
      await _db!.collection('users').doc(uid).update({
        'fcm_token': FieldValue.delete(),
        'fcm_token_updated_at': FieldValue.delete(),
      });
      debugPrint('🗑️ FCM token cleared for $uid');
    } catch (e) {
      debugPrint('⚠️ FcmService.clearTokenForUser: $e');
    }
  }

  /// Reads a recipient's FCM device token from Firestore.
  Future<String?> getTokenForUser(String uid) async {
    if (_db == null || uid.isEmpty) return null;
    try {
      final doc = await _db!.collection('users').doc(uid).get();
      return doc.data()?['fcm_token'] as String?;
    } catch (e) {
      debugPrint('⚠️ FcmService.getTokenForUser: $e');
      return null;
    }
  }

  // ── OAuth2 — FCM v1 API ───────────────────────────────────────────────────

  /// Returns a valid OAuth2 Bearer token for the FCM v1 API.
  ///
  /// Loads the service account JSON from the Flutter asset bundle,
  /// exchanges it for a short-lived access token, and caches the token
  /// until [FcmConfig.tokenRefreshBufferMinutes] before expiry.
  Future<String?> _getAccessToken() async {
    // Return cached token if still valid.
    final now = DateTime.now();
    if (_cachedAccessToken != null &&
        _tokenExpiresAt != null &&
        now.isBefore(
          _tokenExpiresAt!.subtract(
            Duration(minutes: FcmConfig.tokenRefreshBufferMinutes - 55 + 5),
          ),
        )) {
      return _cachedAccessToken;
    }

    try {
      // Load service account JSON from asset bundle.
      final jsonStr = await rootBundle
          .loadString(FcmConfig.serviceAccountAsset);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);

      // Guard: skip if it's still the placeholder template.
      if (jsonMap['project_id'] == 'YOUR_PROJECT_ID' ||
          (jsonMap['private_key'] as String?)
                  ?.contains('YOUR_PRIVATE_KEY') ==
              true) {
        debugPrint(
            '⚠️ FCM service account not configured — push skipped');
        return null;
      }

      // Build credentials and exchange for an OAuth2 access token.
      final credentials = ServiceAccountCredentials.fromJson(jsonMap);
      final client = http.Client();
      try {
        final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
          credentials,
          FcmConfig.scopes,
          client,
        );

        _cachedAccessToken = accessCredentials.accessToken.data;
        _tokenExpiresAt = accessCredentials.accessToken.expiry;
        debugPrint('🔑 FCM OAuth2 token obtained, expires $_tokenExpiresAt');
        return _cachedAccessToken;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('❌ FCM _getAccessToken error: $e');
      return null;
    }
  }

  // ── Send push (FCM HTTP v1 API) ────────────────────────────────────────────

  /// Sends a push notification to a single device token via FCM v1 API.
  ///
  /// [data] is an optional string-keyed payload the receiving app can read.
  ///
  /// Returns true on success, false on any failure (non-throwing).
  Future<bool> sendPush({
    required String toToken,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    if (toToken.isEmpty) {
      debugPrint('⚠️ FCM: empty device token — push skipped');
      return false;
    }

    // Guard: check project ID is configured.
    if (FcmConfig.projectId == 'YOUR_FIREBASE_PROJECT_ID') {
      debugPrint('⚠️ FCM projectId not set in FcmConfig — push skipped');
      return false;
    }

    final accessToken = await _getAccessToken();
    if (accessToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(FcmConfig.sendUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': toToken,
            // Android-specific config.
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'kaamyaab_channel',
                'sound': 'default',
              },
            },
            // iOS-specific config.
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                },
              },
            },
            // Visible notification shown by the OS.
            'notification': {
              'title': title,
              'body': body,
            },
            // Silent data payload readable by the app.
            'data': {
              ...data,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('📤 FCM v1 push sent: $title');
        return true;
      } else {
        // If the token expired (401), clear cached token so next call refreshes.
        if (response.statusCode == 401) {
          _cachedAccessToken = null;
          _tokenExpiresAt = null;
        }
        debugPrint(
            '❌ FCM v1 push failed [${response.statusCode}]: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ FCM v1 sendPush error: $e');
      return false;
    }
  }

  // ── Message handlers ───────────────────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    debugPrint('📩 FCM foreground: ${n.title} — ${n.body}');
    // iOS shows banners natively (configured in init).
    // Android foreground: the Firestore-powered in-app bell handles display.
  }

  void _onNotificationTap(RemoteMessage message) {
    debugPrint('👆 FCM tapped: ${message.data}');
    // TODO: navigate based on message.data['type']
    // e.g. 'booking' → BookingFlowScreen, 'request' → WorkerNotifTab
  }
}
