import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:project_c/flavor/flavor_variables.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_api_call_log.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_upload_story.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

enum HttpMethod { get, post, patch, put, delete }

/// One multipart file part for catalog uploads (field name is usually `photos`).
class CatalogMultipartFile {
  const CatalogMultipartFile({
    required this.field,
    required this.file,
    required this.filename,
    this.contentType,
  });

  final String field;
  final File file;
  final String filename;
  final String? contentType;
}

/// Shared Catalog HTTP client (JSON + multipart via `http`).
///
/// Handles auth headers, 204 bodies, error envelopes, and a single in-flight
/// refresh + one retry on `INVALID_ACCESS_TOKEN`.
class CatalogApiClient {
  CatalogApiClient({
    required SessionStorage sessionStorage,
    Future<String> Function()? deviceIdProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _sessionStorage = sessionStorage,
       _deviceIdProvider = deviceIdProvider,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  static const _tag = 'CatalogApi';
  static const profileHeader = 'X-Catalog-Profile';
  static const deviceHeader = 'X-Catalog-Device-Id';

  /// Bodies at or above this size decode on a worker isolate so large catalog
  /// lists (home, collections, search, wishlist) do not block the UI thread.
  /// Smaller bodies stay on the UI isolate (isolate spawn cost is not worth it).
  static const _largeJsonIsolateBytes = 32 * 1024;

  /// Keys whose values are replaced in debug logs.
  static const _redactKeys = <String>{
    'accessToken',
    'refreshToken',
    'code',
    'Authorization',
    'authorization',
  };

  final SessionStorage _sessionStorage;
  final Future<String> Function()? _deviceIdProvider;
  final http.Client _http;
  final Duration _timeout;

  Future<CatalogTokens>? _refreshInFlight;
  int _sessionEpoch = 0;

  String get _baseUrl {
    final raw = '${getFlavorVariable(FlavorVariables.baseUrl)}';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  void bumpSessionEpoch() {
    _sessionEpoch++;
    CatalogApiCallLog.reset(reason: 'session_epoch');
  }

  Future<Map<String, dynamic>?> sendJson({
    required HttpMethod method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
    bool allowAnonymousBearer = false,
    bool skipAuthRetry = false,
    /// When true, do not attach [profileHeader] (bootstrap recovery / switch).
    bool omitProfileHeader = false,
    /// Override active profile id for this request only.
    String? profileIdOverride,
    Duration? timeout,
  }) async {
    final response = await _execute(
      method: method,
      path: path,
      body: body,
      query: query,
      extraHeaders: extraHeaders,
      requiresAuth: requiresAuth,
      allowAnonymousBearer: allowAnonymousBearer,
      omitProfileHeader: omitProfileHeader,
      profileIdOverride: profileIdOverride,
      timeout: timeout,
    );

    if (_shouldRefreshAndRetry(response) && !skipAuthRetry && requiresAuth) {
      AppLog.d(_tag, 'Access token rejected — refreshing once');
      await refreshSession();
      final retry = await _execute(
        method: method,
        path: path,
        body: body,
        query: query,
        extraHeaders: extraHeaders,
        requiresAuth: true,
        allowAnonymousBearer: false,
        omitProfileHeader: omitProfileHeader,
        profileIdOverride: profileIdOverride,
        timeout: timeout,
      );
      return await _decodeOrThrow(
        retry,
        path,
        method: method.name.toUpperCase(),
      );
    }

    return await _decodeOrThrow(
      response,
      path,
      method: method.name.toUpperCase(),
    );
  }

  /// Multipart POST/PATCH/PUT (profile, store images, collections). Do not set Content-Type.
  Future<Map<String, dynamic>?> sendMultipart({
    required String path,
    required Map<String, String> fields,
    required List<CatalogMultipartFile> files,
    HttpMethod method = HttpMethod.post,
    bool requiresAuth = true,
    bool skipAuthRetry = false,
    bool omitProfileHeader = false,
    String? profileIdOverride,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final httpMethod = switch (method) {
      HttpMethod.patch => HttpMethod.patch,
      HttpMethod.put => HttpMethod.put,
      _ => HttpMethod.post,
    };
    final methodLabel = switch (httpMethod) {
      HttpMethod.patch => 'PATCH',
      HttpMethod.put => 'PUT',
      _ => 'POST',
    };
    final response = await _executeMultipart(
      method: httpMethod,
      path: path,
      fields: fields,
      files: files,
      requiresAuth: requiresAuth,
      omitProfileHeader: omitProfileHeader,
      profileIdOverride: profileIdOverride,
      timeout: timeout,
    );

    if (_shouldRefreshAndRetry(response) && !skipAuthRetry && requiresAuth) {
      AppLog.d(_tag, 'Access token rejected — refreshing once (multipart)');
      await refreshSession();
      final retry = await _executeMultipart(
        method: httpMethod,
        path: path,
        fields: fields,
        files: files,
        requiresAuth: true,
        omitProfileHeader: omitProfileHeader,
        profileIdOverride: profileIdOverride,
        timeout: timeout,
      );
      return await _decodeOrThrow(retry, path, method: methodLabel);
    }

    return await _decodeOrThrow(response, path, method: methodLabel);
  }

  Future<CatalogTokens> refreshSession() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final epoch = _sessionEpoch;
    final future = _performRefresh(epoch);
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<CatalogTokens> _performRefresh(int epoch) async {
    final tokens = await _sessionStorage.readTokens();
    final refresh = tokens?.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw CatalogApiException(
        statusCode: 401,
        code: 'INVALID_REFRESH_TOKEN',
        message: 'Missing refresh token',
      );
    }

    final response = await _rawRequest(
      method: HttpMethod.post,
      path: Endpoints.refreshToken,
      body: {'refreshToken': refresh},
      accessToken: null,
    );

    if (epoch != _sessionEpoch) {
      throw CatalogApiException(
        statusCode: 401,
        code: 'SESSION_REVOKED',
        message: 'Session changed during refresh',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _sessionStorage.clear();
      bumpSessionEpoch();
      throw _parseError(
        response,
        path: Endpoints.refreshToken,
        method: 'POST',
      );
    }

    final map = _decodeMap(response.body);
    _logDecodedResponse(
      path: Endpoints.refreshToken,
      method: 'POST',
      statusCode: response.statusCode,
      decoded: map,
    );
    final next = CatalogTokens.fromJson(map);
    await _sessionStorage.saveTokens(next);
    AppLog.d(_tag, 'Refresh succeeded');
    return next;
  }

  Future<http.Response> _execute({
    required HttpMethod method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? extraHeaders,
    required bool requiresAuth,
    required bool allowAnonymousBearer,
    bool omitProfileHeader = false,
    String? profileIdOverride,
    Duration? timeout,
  }) async {
    String? access;
    if (requiresAuth || allowAnonymousBearer) {
      access = (await _sessionStorage.readTokens())?.accessToken;
      if (requiresAuth && (access == null || access.isEmpty)) {
        throw CatalogApiException(
          statusCode: 401,
          code: 'AUTH_REQUIRED',
          message: 'Not signed in',
        );
      }
      if (!requiresAuth && (access == null || access.isEmpty)) {
        access = null;
      }
    }

    final headers = await _contextHeaders(
      requiresAuth: requiresAuth,
      omitProfileHeader: omitProfileHeader,
      profileIdOverride: profileIdOverride,
      extraHeaders: extraHeaders,
    );

    return _rawRequest(
      method: method,
      path: path,
      body: body,
      query: query,
      extraHeaders: headers,
      accessToken: access,
      timeout: timeout,
    );
  }

  Future<http.Response> _executeMultipart({
    required HttpMethod method,
    required String path,
    required Map<String, String> fields,
    required List<CatalogMultipartFile> files,
    required bool requiresAuth,
    bool omitProfileHeader = false,
    String? profileIdOverride,
    required Duration timeout,
  }) async {
    final access = (await _sessionStorage.readTokens())?.accessToken;
    if (requiresAuth && (access == null || access.isEmpty)) {
      throw CatalogApiException(
        statusCode: 401,
        code: 'AUTH_REQUIRED',
        message: 'Not signed in',
      );
    }

    final methodLabel = switch (method) {
      HttpMethod.patch => 'PATCH',
      HttpMethod.put => 'PUT',
      _ => 'POST',
    };
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest(methodLabel, uri);
    request.headers['Accept'] = 'application/json';
    if (access != null && access.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $access';
    }
    final context = await _contextHeaders(
      requiresAuth: requiresAuth,
      omitProfileHeader: omitProfileHeader,
      profileIdOverride: profileIdOverride,
    );
    request.headers.addAll(context);
    request.fields.addAll(fields);

    for (final part in files) {
      request.files.add(
        await http.MultipartFile.fromPath(
          part.field,
          part.file.path,
          filename: part.filename,
        ),
      );
    }

    final fullUrl = uri.toString();
    CatalogApiCallLog.record(method: methodLabel, path: path);
    _logOutgoingMultipartRequest(
      methodLabel: methodLabel,
      fullUrl: fullUrl,
      path: path,
      fields: fields,
      fileNames: [for (final f in files) f.filename],
    );
    if (kDebugMode &&
        CatalogUploadStory.isUploadApiPath(path, method: methodLabel)) {
      CatalogUploadStory.note(
        'Legacy multipart $methodLabel $path (prefer Direct-to-S3). '
        'files=${files.length}',
      );
    }

    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      return response;
    } on TimeoutException {
      AppLog.e(_tag, 'Timeout on $fullUrl');
      throw CatalogApiException(
        statusCode: 408,
        code: 'TIMEOUT',
        message: 'Request timed out',
      );
    } on http.ClientException catch (e) {
      AppLog.e(_tag, 'Network error on $fullUrl', e);
      throw CatalogApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: e.message,
      );
    }
  }

  /// Device + optional active profile headers for account-scoped calls.
  Future<Map<String, String>> _contextHeaders({
    required bool requiresAuth,
    bool omitProfileHeader = false,
    String? profileIdOverride,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{};
    final provider = _deviceIdProvider;
    if (provider != null) {
      try {
        final deviceId = (await provider()).trim();
        if (deviceId.isNotEmpty) {
          headers[deviceHeader] = deviceId;
        }
      } catch (e) {
        AppLog.e(_tag, 'Failed to resolve device id', e);
      }
    }

    if (requiresAuth && !omitProfileHeader) {
      final override = profileIdOverride?.trim() ?? '';
      final stored =
          override.isNotEmpty
              ? override
              : ((await _sessionStorage.readActiveProfileId())?.trim() ?? '');
      if (stored.isNotEmpty) {
        headers[profileHeader] = stored;
      }
    }

    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<http.Response> _rawRequest({
    required HttpMethod method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? extraHeaders,
    String? accessToken,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: query?.isEmpty ?? true ? null : query);

    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    if (extraHeaders != null && extraHeaders.isNotEmpty) {
      headers.addAll(extraHeaders);
    }

    final methodLabel = method.name.toUpperCase();
    final fullUrl = uri.toString();
    CatalogApiCallLog.record(
      method: methodLabel,
      path: path,
      query: query,
    );
    _logOutgoingJsonRequest(
      methodLabel: methodLabel,
      fullUrl: fullUrl,
      path: path,
      body: body,
    );
    CatalogUploadStory.apiRequest(
      method: methodLabel,
      path: path,
      body: body,
    );

    try {
      final encoded = body == null ? null : jsonEncode(body);
      late final http.Response response;
      switch (method) {
        case HttpMethod.get:
          response = await _http
              .get(uri, headers: headers)
              .timeout(effectiveTimeout);
        case HttpMethod.post:
          response = await _http
              .post(uri, headers: headers, body: encoded)
              .timeout(effectiveTimeout);
        case HttpMethod.patch:
          response = await _http
              .patch(uri, headers: headers, body: encoded)
              .timeout(effectiveTimeout);
        case HttpMethod.put:
          response = await _http
              .put(uri, headers: headers, body: encoded)
              .timeout(effectiveTimeout);
        case HttpMethod.delete:
          response = await _http
              .delete(uri, headers: headers, body: encoded)
              .timeout(effectiveTimeout);
      }

      return response;
    } on TimeoutException {
      AppLog.e(_tag, 'Timeout on $fullUrl');
      throw CatalogApiException(
        statusCode: 408,
        code: 'TIMEOUT',
        message: 'Request timed out',
      );
    } on http.ClientException catch (e) {
      AppLog.e(_tag, 'Network error on $fullUrl', e);
      throw CatalogApiException(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: e.message,
      );
    }
  }

  /// Debug-only request log. Never sanitize/encode bodies outside [kDebugMode].
  void _logOutgoingJsonRequest({
    required String methodLabel,
    required String fullUrl,
    required String path,
    Map<String, dynamic>? body,
  }) {
    if (!kDebugMode) return;
    AppLog.d(_tag, '──────── REQUEST ────────');
    AppLog.d(_tag, '$methodLabel $fullUrl');
    AppLog.d(_tag, 'baseUrl=$_baseUrl | endpoint=$path');
    AppLog.d(
      _tag,
      'requestBody=${body == null ? '(none)' : _sanitizeForLog(body)}',
    );
    if (CatalogMediaDebug.isMediaApiPath(path)) {
      CatalogMediaDebug.api(
        'REQUEST $methodLabel $path '
        'body=${CatalogMediaDebug.requestBodyHint(body)}',
      );
    }
  }

  /// Debug-only multipart request log.
  void _logOutgoingMultipartRequest({
    required String methodLabel,
    required String fullUrl,
    required String path,
    required Map<String, String> fields,
    required List<String> fileNames,
  }) {
    if (!kDebugMode) return;
    AppLog.d(_tag, '──────── REQUEST ────────');
    AppLog.d(_tag, '$methodLabel $fullUrl (multipart)');
    AppLog.d(_tag, 'baseUrl=$_baseUrl | endpoint=$path');
    AppLog.d(
      _tag,
      'requestBody={fields: $fields, files: $fileNames}',
    );
    if (CatalogMediaDebug.isMediaApiPath(path)) {
      CatalogMediaDebug.api(
        'REQUEST $methodLabel $path multipart files=$fileNames',
      );
    }
  }

  /// Debug-only response log using an already-decoded body (no second jsonDecode).
  void _logDecodedResponse({
    required String path,
    required String method,
    required int statusCode,
    required Object? decoded,
  }) {
    if (!kDebugMode) return;
    AppLog.d(_tag, '──────── RESPONSE ────────');
    AppLog.d(_tag, 'endpoint=$path');
    AppLog.d(_tag, 'statusCode=$statusCode');
    if (decoded == null) {
      AppLog.d(_tag, 'responseBody=(empty/204)');
      if (CatalogMediaDebug.isMediaApiPath(path)) {
        CatalogMediaDebug.api('RESPONSE $statusCode $path body=(empty)');
      }
      return;
    }
    if (decoded is Map<String, dynamic>) {
      AppLog.full(_tag, 'responseBody', _redactMap(decoded));
    } else {
      AppLog.full(_tag, 'responseBody', decoded);
    }
    if (CatalogMediaDebug.isMediaApiPath(path)) {
      final summary = CatalogMediaDebug.summarizeMediaJson(decoded);
      CatalogMediaDebug.api('RESPONSE $statusCode $path $summary');
      if (summary.contains('GAP_THUMBHASH_NULL')) {
        CatalogMediaDebug.gap(
          'API thumbhash missing in $path status=$statusCode',
        );
      }
    }
    CatalogUploadStory.apiResponse(
      method: method,
      path: path,
      statusCode: statusCode,
      decoded: decoded,
    );
  }

  String _sanitizeForLog(Map<String, dynamic> map) {
    final sanitized = _redactMap(map);
    return jsonEncode(sanitized);
  }

  dynamic _redactMap(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, nested) {
        final keyStr = '$key';
        if (_redactKeys.contains(keyStr)) {
          out[keyStr] = '***';
        } else if (keyStr == 'tokens' && nested is Map) {
          out[keyStr] = _redactMap(nested);
        } else {
          out[keyStr] = _redactMap(nested);
        }
      });
      return out;
    }
    if (value is List) {
      return value.map(_redactMap).toList();
    }
    return value;
  }

  bool _shouldRefreshAndRetry(http.Response response) {
    if (response.statusCode != 401) return false;
    try {
      final map = _decodeMap(response.body);
      final error = map['error'];
      if (error is Map<String, dynamic>) {
        return error['code'] == 'INVALID_ACCESS_TOKEN';
      }
    } catch (_) {}
    return false;
  }

  /// Decode JSON text. Large bodies use [compute] so the UI isolate stays free.
  Future<dynamic> _decodeJsonBody(String body) async {
    if (body.length < _largeJsonIsolateBytes) {
      return jsonDecode(body);
    }
    AppLog.d(
      _tag,
      'Large JSON (${body.length} bytes) — decode via compute()',
    );
    // [jsonDecode] is a top-level tear-off — safe for [compute].
    return compute(jsonDecode, body);
  }

  Map<String, dynamic> _requireJsonObject(dynamic decoded, int statusCode) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw CatalogApiException(
      statusCode: statusCode,
      code: 'UNEXPECTED_RESPONSE',
      message: 'Unexpected response format',
    );
  }

  /// Single jsonDecode for success bodies; debug logs reuse that result.
  Future<Map<String, dynamic>?> _decodeOrThrow(
    http.Response response,
    String path, {
    String method = '',
  }) async {
    if (response.statusCode == 204) {
      _logDecodedResponse(
        path: path,
        method: method,
        statusCode: response.statusCode,
        decoded: null,
      );
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        _logDecodedResponse(
          path: path,
          method: method,
          statusCode: response.statusCode,
          decoded: null,
        );
        return <String, dynamic>{};
      }
      final decoded = await _decodeJsonBody(response.body);
      final map = _requireJsonObject(decoded, response.statusCode);
      _logDecodedResponse(
        path: path,
        method: method,
        statusCode: response.statusCode,
        decoded: map,
      );
      return map;
    }

    throw _parseError(response, path: path, method: method);
  }

  CatalogApiException _parseError(
    http.Response response, {
    String path = '',
    String method = '',
  }) {
    var code = 'HTTP_${response.statusCode}';
    var message = 'Request failed';
    var details = <dynamic>[];
    var failedPhotos = <FailedPhoto>[];
    int? retryAfter;

    final retryHeader = response.headers['retry-after'];
    if (retryHeader != null) {
      retryAfter = int.tryParse(retryHeader);
    }

    try {
      if (response.body.isNotEmpty) {
        final map = _decodeMap(response.body);
        // One decode for error handling; reuse for debug logs (no second parse).
        _logDecodedResponse(
          path: path.isEmpty ? '(error)' : path,
          method: method,
          statusCode: response.statusCode,
          decoded: map,
        );
        final error = map['error'];
        if (error is Map<String, dynamic>) {
          code = error['code'] as String? ?? code;
          message = error['message'] as String? ?? message;
          final rawDetails = error['details'];
          if (rawDetails is List) details = List<dynamic>.from(rawDetails);
          final rawFailed = error['failedPhotos'];
          if (rawFailed is List) {
            failedPhotos =
                rawFailed
                    .whereType<Map<String, dynamic>>()
                    .map(FailedPhoto.fromJson)
                    .toList();
          }
        } else if (map['message'] is String) {
          message = map['message'] as String;
        }
      } else {
        _logDecodedResponse(
          path: path.isEmpty ? '(error)' : path,
          method: method,
          statusCode: response.statusCode,
          decoded: null,
        );
      }
    } catch (_) {
      // Keep defaults when body is not catalog JSON.
      if (kDebugMode && response.body.isNotEmpty) {
        AppLog.full(_tag, 'responseBody', response.body);
      }
    }

    AppLog.e(_tag, 'API error $code (${response.statusCode})');
    _logProfileSwitchingApiError(code, response.statusCode);
    return CatalogApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      details: details,
      failedPhotos: failedPhotos,
      retryAfterSeconds: retryAfter,
    );
  }

  void _logProfileSwitchingApiError(String code, int statusCode) {
    switch (code) {
      case 'DEVICE_ID_REQUIRED':
      case 'INVALID_DEVICE_ID':
      case 'DEVICE_ID_MISMATCH':
        ProfileSwitchingLog.e(
          'PS-05',
          'API $code status=$statusCode',
        );
      case 'PROFILE_ACCESS_REMOVED':
        ProfileSwitchingLog.d(
          'PS-53/54/72',
          'API PROFILE_ACCESS_REMOVED status=$statusCode',
        );
      case 'OWNED_STORE_LIMIT_REACHED':
        ProfileSwitchingLog.d(
          'PS-33',
          'API OWNED_STORE_LIMIT_REACHED status=$statusCode',
        );
      case 'OWNER_CANNOT_LEAVE':
        ProfileSwitchingLog.d(
          'PS-51',
          'API OWNER_CANNOT_LEAVE status=$statusCode',
        );
      case 'INVITATION_NOT_PENDING':
        ProfileSwitchingLog.d(
          'PS-75',
          'API INVITATION_NOT_PENDING status=$statusCode',
        );
      case 'PROFILE_REQUIRED':
        ProfileSwitchingLog.d(
          'PS-06',
          'API PROFILE_REQUIRED status=$statusCode (name onboarding)',
        );
      default:
        break;
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  void dispose() {
    _http.close();
  }
}
