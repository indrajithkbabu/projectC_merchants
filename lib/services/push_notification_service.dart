import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:project_c/firebase_options.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/main/app.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/notification/device_token_repository.dart';

/// Top-level FCM background handler (must be a top-level or static function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PushNotificationService._dbg(
    'background message id=${message.messageId} data=${message.data}',
  );
}

/// Firebase Cloud Messaging + catalog device-token sync + deep links.
///
/// Lifecycle:
/// - [initialize]: local notifications + message listeners (no Bearer yet).
///   Runtime notification permission is deferred until an Activity exists
///   ([requestRuntimePermissions] after first frame / before getToken).
/// - [onSignedIn]: permission → FCM token → `POST /devices/token` with Bearer.
/// - [onSigningOut]: `DELETE /devices/token` while Bearer still valid.
///
/// Deep links never alter auth/shell roots; they only [Navigator.pushNamed]
/// when signed in and args are valid.
class PushNotificationService {
  PushNotificationService({
    required CatalogSession session,
    required DeviceTokenRepository deviceTokenRepository,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _session = session,
       _deviceTokens = deviceTokenRepository,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Filter logcat / Flutter console with: `FCM_DEBUG`
  static const filterTag = 'FCM_DEBUG';
  static const _tag = 'PushNotification';
  static const _nativeChannel = MethodChannel('project_c/fcm_debug');
  /// Bump when shipping FCM debug builds so logs prove the APK is fresh.
  static const debugBuildStamp = 'fcm-debug-2026-10-09d';
  static const androidChannelId = 'project_c_default';
  static const androidChannelName = 'General';
  static const androidChannelDescription =
      'General notifications from JewelFlow';

  /// Always-on debug line (works in release). Filter: [FCM_DEBUG]
  static void _dbg(String message) {
    // ignore: avoid_print
    print('[$filterTag] $message');
  }

  final CatalogSession _session;
  final DeviceTokenRepository _deviceTokens;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenSub;
  bool _initialized = false;
  bool _backendSyncInFlight = false;
  bool _runtimePermissionAsked = false;
  bool _getTokenInFlight = false;
  DateTime? _lastResumeRetryAt;

  /// Queued when a notification is opened before session restore finishes.
  Map<String, dynamic>? _pendingOpenData;

  bool get isInitialized => _initialized;

  /// Current FCM registration token (null until signed-in fetch succeeds).
  String? fcmToken;

  bool get _hasFcm => (fcmToken?.trim() ?? '').isNotEmpty;
  bool get _hasAccess =>
      (_session.tokens?.accessToken.trim() ?? '').isNotEmpty;

  /// Cold-start setup: listeners only. Does **not** need accessToken.
  /// Runtime permission must wait for Activity ([requestRuntimePermissions]).
  Future<void> initialize() async {
    if (_initialized) {
      _dbg('initialize SKIP already initialized');
      return;
    }

    final opts = DefaultFirebaseOptions.currentPlatform;
    _dbg('──────── INIT START stamp=$debugBuildStamp ────────');
    _dbg(
      'firebase projectId=${opts.projectId} '
      'appId=${opts.appId} '
      'senderId=${opts.messagingSenderId} '
      'platform=$_platformLabel',
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _messaging.setAutoInitEnabled(true);
    await _logPlayServices();

    // Do NOT request POST_NOTIFICATIONS here — Activity is not attached yet
    // (called from main() before runApp). Dialog would never show.
    _dbg(
      'permission DEFERRED until Activity ready '
      '(requestRuntimePermissions / onSignedIn)',
    );

    _tokenSub = _messaging.onTokenRefresh.listen((token) async {
      fcmToken = token;
      _dbg('token REFRESHED len=${token.length}');
      // Only register when Bearer session exists.
      if (_session.isSignedIn && _hasAccess) {
        await syncTokenWithBackend(reason: 'token_refresh');
      } else {
        _dbg('token refresh held until signed in');
      }
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onOpened(initial);
      });
    }

    _initialized = true;
    _dbg(
      '──────── INIT END (token+backend deferred until onSignedIn) '
      'signedIn=${_session.isSignedIn} ────────',
    );
  }

  /// Call after first frame (Activity attached) so Android 13+ shows the
  /// system notification permission dialog. Safe to call multiple times.
  Future<void> requestRuntimePermissions() async {
    if (_runtimePermissionAsked) {
      _dbg('runtimePermission SKIP already asked');
      return;
    }
    _runtimePermissionAsked = true;
    _dbg('──────── runtimePermission START ────────');

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _local
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      // Android 13+ (API 33): shows system dialog. Older: returns true, no dialog.
      final granted = await androidPlugin?.requestNotificationsPermission();
      _dbg(
        'android POST_NOTIFICATIONS granted=$granted '
        '(null/true on API<33 = no dialog expected)',
      );
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    _dbg('firebase permission=${settings.authorizationStatus}');

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apns = await _messaging.getAPNSToken();
      _dbg('apnsToken ${apns == null || apns.isEmpty ? "MISSING" : "ok"}');
    }

    _dbg('──────── runtimePermission END ────────');
  }

  /// After OTP verify / session restore — Bearer exists. Fetch FCM then POST.
  Future<void> onSignedIn() async {
    _dbg(
      '──────── onSignedIn START hasFcm=${_hasFcm} '
      'hasAccess=${_hasAccess} ────────',
    );

    if (!_hasAccess) {
      _dbg('onSignedIn ABORT no accessToken yet');
      return;
    }

    // Ensure system notification prompt ran with Activity attached.
    await requestRuntimePermissions();
    await _logPlayServices();
    await _logFirebaseInstallations();

    // iOS: ensure APNs before getToken.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apns = await _messaging.getAPNSToken();
      _dbg('apnsToken ${apns == null || apns.isEmpty ? "MISSING" : "ok"}');
    }

    if (!_hasFcm) {
      // Brief settle — some OEMs need Play Services online before register.
      _dbg('getToken settle wait 2s');
      await Future<void>.delayed(const Duration(seconds: 2));
      _dbg('getToken START (after auth, 3 attempts)');
      await _refreshToken(retries: 3);
      // Hard failures / bad FID: wipe local FCM + Installation, mint new FID,
      // then retry (does not affect catalog auth/session).
      if (!_hasFcm) {
        _dbg('getToken recover: deleteToken + delete Installation FID');
        try {
          await _messaging.deleteToken();
        } catch (e) {
          _dbg('deleteToken ignored | $e');
        }
        try {
          await FirebaseInstallations.instance.delete();
          final id = await FirebaseInstallations.instance.getId();
          _dbg('installationsId RESET ok len=${id.length}');
        } catch (e) {
          _dbg('installations reset ignored | $e');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
        await _refreshToken(retries: 3);
      }
    } else {
      _dbg('getToken SKIP already have fcm token');
    }

    await syncTokenWithBackend(reason: 'on_signed_in');
    flushPendingOpen();
    _dbg(
      '──────── onSignedIn END hasFcm=${_hasFcm} '
      'hasAccess=${_hasAccess} ────────',
    );
  }

  /// Call **before** clearing the local session on logout / delete account.
  Future<void> onSigningOut() async {
    _dbg('onSigningOut');
    await unregisterTokenFromBackend();
    _pendingOpenData = null;
  }

  /// App foregrounded — retry FCM if signed in but still missing a token.
  ///
  /// Covers transient GMS `SERVICE_NOT_AVAILABLE` (OEM / Play Services /
  /// network) after the user clears GMS cache, switches network, or waits.
  Future<void> onAppResumed() async {
    if (!_initialized) return;
    if (!_session.isSignedIn || !_hasAccess) return;
    if (_hasFcm) {
      // Token already held — still ensure backend has it (idempotent).
      return;
    }
    if (_getTokenInFlight) {
      _dbg('resumeRetry SKIP getToken in flight');
      return;
    }
    final last = _lastResumeRetryAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) {
      _dbg('resumeRetry SKIP throttled');
      return;
    }
    _lastResumeRetryAt = DateTime.now();
    _dbg('──────── resumeRetry START (SERVICE_NOT_AVAILABLE recovery) ────────');
    await _logPlayServices();
    await _refreshToken(retries: 2);
    if (_hasFcm) {
      await syncTokenWithBackend(reason: 'resume_retry');
    } else {
      _dbg(
        'resumeRetry still no token — Xiaomi/MIUI: clear cache for '
        'Google Play Services + Google Services Framework, Autostart on, '
        'no battery restrict; or try VPN / another network',
      );
    }
    _dbg('──────── resumeRetry END hasFcm=$_hasFcm ────────');
  }

  /// Registers the current FCM token with the catalog API when signed in.
  Future<void> syncTokenWithBackend({String reason = 'unspecified'}) async {
    final token = fcmToken?.trim() ?? '';
    final accessToken = _session.tokens?.accessToken.trim() ?? '';

    if (!_session.isSignedIn || accessToken.isEmpty) {
      _dbg(
        'sync SKIP reason=$reason not_signed_in '
        '(accessToken only exists after auth)',
      );
      return;
    }
    if (token.isEmpty) {
      _dbg(
        'sync SKIP reason=$reason no_fcm_token '
        '(POST /devices/token not called)',
      );
      return;
    }
    if (_backendSyncInFlight) {
      _dbg('sync SKIP reason=$reason in_flight');
      return;
    }

    _dbg(
      'sync reason=$reason signedIn=true hasFcm=true hasAccess=true '
      'platform=$_platformLabel',
    );
    // TEMP debug: full tokens for backend/FCM verification — remove later.
    _dbg('accessToken=$accessToken');
    _dbg('fcmToken=$token');

    _backendSyncInFlight = true;
    try {
      _dbg('POST /devices/token START');
      await _deviceTokens.registerToken(
        token: token,
        platform: _platformLabel,
      );
      _dbg('POST /devices/token OK backend_token_registered');
    } catch (e) {
      _dbg('POST /devices/token FAIL $e');
      AppLog.e(_tag, 'backend token register failed', e);
    } finally {
      _backendSyncInFlight = false;
    }
  }

  Future<void> unregisterTokenFromBackend() async {
    final token = fcmToken?.trim() ?? '';
    if (token.isEmpty || !_session.isSignedIn) {
      _dbg(
        'unregister SKIP hasFcm=${token.isNotEmpty} '
        'signedIn=${_session.isSignedIn}',
      );
      return;
    }
    try {
      _dbg('DELETE /devices/token START');
      await _deviceTokens.unregisterToken(token: token);
      _dbg('DELETE /devices/token OK');
    } catch (e) {
      // Local logout must proceed even if unregister fails.
      _dbg('DELETE /devices/token FAIL $e');
      AppLog.e(_tag, 'backend token unregister failed', e);
    }
  }

  /// Re-attempt a deferred deep link (e.g. after cold-start auth restore).
  void flushPendingOpen() {
    final pending = _pendingOpenData;
    if (pending == null) return;
    _pendingOpenData = null;
    _handleNotificationData(pending);
  }

  String get _platformLabel {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'android';
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    final androidPlugin =
        _local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        androidChannelId,
        androidChannelName,
        description: androidChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  Future<void> _logPlayServices() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final availability =
          await GoogleApiAvailability.instance
              .checkGooglePlayServicesAvailability();
      _dbg('playServices=$availability');
      if (availability != GooglePlayServicesAvailability.success) {
        _dbg(
          'playServices WARN FCM getToken needs Google Play Services '
          '(success). Current=$availability',
        );
      }
    } catch (e) {
      _dbg('playServices check failed | $e');
    }
  }

  Future<void> _logFirebaseInstallations() async {
    try {
      final id = await FirebaseInstallations.instance.getId();
      _dbg(
        'installationsId=${id.isEmpty ? "EMPTY" : "ok len=${id.length}"}',
      );
    } catch (e) {
      _dbg('installationsId FAIL | $e');
    }
  }

  Future<void> _refreshToken({int retries = 1}) async {
    if (_getTokenInFlight) {
      _dbg('getToken SKIP already in flight');
      return;
    }
    _getTokenInFlight = true;
    var sawServiceNotAvailable = false;
    try {
      var attempt = 0;
      while (attempt < retries) {
        attempt += 1;
        try {
          _dbg('getToken attempt=$attempt/$retries …');
          fcmToken = await _messaging.getToken();
          if (fcmToken != null && fcmToken!.trim().isNotEmpty) {
            _dbg(
              'getToken OK attempt=$attempt len=${fcmToken!.trim().length}',
            );
            return;
          }
          _dbg('getToken EMPTY attempt=$attempt/$retries');
        } catch (e) {
          _dbg('getToken FAIL attempt=$attempt/$retries | $e');
          if (e is FirebaseException) {
            _dbg(
              'getToken FirebaseException code=${e.code} '
              'plugin=${e.plugin} message=${e.message}',
            );
          }
          // Native probe unwraps IOException cause chain (SERVICE_NOT_AVAILABLE,
          // Invalid argument for the given fid, AUTHENTICATION_FAILED, …).
          final chain = await _probeNativeTokenCause();
          if (_looksLikeServiceNotAvailable('$e $chain')) {
            sawServiceNotAvailable = true;
          }
          AppLog.e(_tag, 'getToken failed attempt=$attempt/$retries', e);
        }
        if (_hasFcm) return;
        if (attempt < retries) {
          // SERVICE_NOT_AVAILABLE needs longer gaps; GMS often recovers slowly.
          final waitSec =
              sawServiceNotAvailable ? (attempt * 5) : (attempt * 2);
          _dbg('getToken wait ${waitSec}s then retry');
          await Future<void>.delayed(Duration(seconds: waitSec));
        }
      }
      if (sawServiceNotAvailable) {
        _dbg(
          'getToken DIAGNOSIS=SERVICE_NOT_AVAILABLE '
          '(Play Services ↔ Google FCM path). Not SHA/API-key/auth. '
          'Installations OK + this error = OEM/GMS/network. '
          'Xiaomi: Settings→Apps→Google Play Services→Clear cache; '
          'same for Google Services Framework; enable Autostart; '
          'unrestrict battery; update Play Services; try VPN.',
        );
      }
      _dbg('getToken GAVE_UP hasFcm=false');
    } finally {
      _getTokenInFlight = false;
    }
  }

  bool _looksLikeServiceNotAvailable(String text) {
    return text.toUpperCase().contains('SERVICE_NOT_AVAILABLE');
  }

  /// Returns the native cause chain (empty on success / skip / error).
  Future<String> _probeNativeTokenCause() async {
    if (defaultTargetPlatform != TargetPlatform.android) return '';
    try {
      final raw = await _nativeChannel.invokeMethod<dynamic>(
        'getTokenWithCause',
      );
      if (raw is! Map) {
        _dbg('nativeProbe unexpected=$raw');
        return '';
      }
      final ok = raw['ok'] == true;
      final chain = '${raw['chain'] ?? ''}';
      final token = '${raw['token'] ?? ''}';
      if (ok && token.trim().isNotEmpty) {
        fcmToken = token.trim();
        _dbg('nativeProbe OK recovered token len=${fcmToken!.length}');
        return '';
      }
      _dbg('nativeProbe FAIL causeChain=$chain');
      return chain;
    } catch (e) {
      _dbg('nativeProbe invoke failed | $e');
      return '$e';
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    _dbg(
      'foreground id=${message.messageId} type=${message.data['type']}',
    );
    final notification = message.notification;
    if (notification == null) return;

    final payload = jsonEncode(message.data);
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          channelDescription: androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        _handleNotificationData(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      AppLog.e(_tag, 'local tap payload parse failed', e);
    }
  }

  void _onOpened(RemoteMessage message) {
    _dbg('opened id=${message.messageId} data=${message.data}');
    _handleNotificationData(Map<String, dynamic>.from(message.data));
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    if (!_session.isSignedIn) {
      _pendingOpenData = data;
      _dbg('open DEFER until signed in type=${data['type']}');
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingOpenData = data;
      _dbg('open DEFER navigator not ready type=${data['type']}');
      return;
    }

    final type = '${data['type'] ?? ''}'.trim();
    final storeId = '${data['storeId'] ?? data['store_id'] ?? ''}'.trim();
    final listingId =
        '${data['listingId'] ?? data['listing_id'] ?? ''}'.trim();
    final storeName =
        '${data['storeName'] ?? data['store_name'] ?? ''}'.trim();

    switch (type) {
      case 'follow_request':
        // Owner inbox for the store that received the request.
        if (storeId.isEmpty) return;
        nav.pushNamed(
          Routes.followRequestsRoute,
          arguments: <String, Object?>{
            'storeId': storeId,
            'storeName': storeName.isEmpty ? 'My store' : storeName,
          },
        );
        return;
      case 'request_approved':
        // Requester → the store that accepted.
        if (storeId.isEmpty) return;
        nav.pushNamed(
          Routes.storeProfileRoute,
          arguments: <String, Object?>{
            'storeId': storeId,
            'storeName': storeName.isEmpty ? 'Store' : storeName,
            'isOwnStore': false,
          },
        );
        return;
      case 'new_follower':
        // Owner → own store profile (storeId is the followed store).
        if (storeId.isEmpty) return;
        final ownId = _session.ownStoreId?.trim() ?? '';
        nav.pushNamed(
          Routes.storeProfileRoute,
          arguments: <String, Object?>{
            'storeId': storeId,
            'storeName': storeName.isEmpty ? 'My store' : storeName,
            'isOwnStore': ownId.isEmpty || ownId == storeId,
          },
        );
        return;
      case 'new_upload':
        // Follower → store that uploaded (+ listing when present).
        if (storeId.isEmpty) return;
        nav.pushNamed(
          Routes.storeProfileRoute,
          arguments: <String, Object?>{
            'storeId': storeId,
            'storeName': storeName.isEmpty ? 'Store' : storeName,
            'isOwnStore': false,
            if (listingId.isNotEmpty) 'focusProductId': listingId,
          },
        );
        return;
      default:
        // Unknown / missing type: if storeId present, open that store.
        if (storeId.isNotEmpty) {
          final ownId = _session.ownStoreId?.trim() ?? '';
          nav.pushNamed(
            Routes.storeProfileRoute,
            arguments: <String, Object?>{
              'storeId': storeId,
              'storeName': storeName.isEmpty ? 'Store' : storeName,
              'isOwnStore': ownId.isNotEmpty && ownId == storeId,
              if (listingId.isNotEmpty) 'focusProductId': listingId,
            },
          );
          return;
        }
        AppLog.d(_tag, 'ignored open type=$type');
    }
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
    _tokenSub = null;
  }
}
