import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:project_c/flavor/flavor_variables.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

enum HttpMethod { get, post, patch, delete }

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
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _sessionStorage = sessionStorage,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  static const _tag = 'CatalogApi';

  /// Keys whose values are replaced in debug logs.
  static const _redactKeys = <String>{
    'accessToken',
    'refreshToken',
    'code',
    'Authorization',
    'authorization',
  };

  final SessionStorage _sessionStorage;
  final http.Client _http;
  final Duration _timeout;

  Future<CatalogTokens>? _refreshInFlight;
  int _sessionEpoch = 0;

  String get _baseUrl {
    final raw = '${getFlavorVariable(FlavorVariables.baseUrl)}';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  void bumpSessionEpoch() => _sessionEpoch++;

  Future<Map<String, dynamic>?> sendJson({
    required HttpMethod method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool requiresAuth = true,
    bool allowAnonymousBearer = false,
    bool skipAuthRetry = false,
    Duration? timeout,
  }) async {
    final response = await _execute(
      method: method,
      path: path,
      body: body,
      query: query,
      requiresAuth: requiresAuth,
      allowAnonymousBearer: allowAnonymousBearer,
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
        requiresAuth: true,
        allowAnonymousBearer: false,
        timeout: timeout,
      );
      return _decodeOrThrow(retry, path);
    }

    return _decodeOrThrow(response, path);
  }

  /// Multipart POST/PATCH (collection create / add photos). Do not set Content-Type.
  Future<Map<String, dynamic>?> sendMultipart({
    required String path,
    required Map<String, String> fields,
    required List<CatalogMultipartFile> files,
    HttpMethod method = HttpMethod.post,
    bool requiresAuth = true,
    bool skipAuthRetry = false,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final httpMethod =
        method == HttpMethod.patch ? HttpMethod.patch : HttpMethod.post;
    final response = await _executeMultipart(
      method: httpMethod,
      path: path,
      fields: fields,
      files: files,
      requiresAuth: requiresAuth,
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
        timeout: timeout,
      );
      return _decodeOrThrow(retry, path);
    }

    return _decodeOrThrow(response, path);
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
      throw _parseError(response);
    }

    final map = _decodeMap(response.body);
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
    required bool requiresAuth,
    required bool allowAnonymousBearer,
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

    return _rawRequest(
      method: method,
      path: path,
      body: body,
      query: query,
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

    final methodLabel = method == HttpMethod.patch ? 'PATCH' : 'POST';
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest(methodLabel, uri);
    request.headers['Accept'] = 'application/json';
    if (access != null && access.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $access';
    }
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
    AppLog.d(_tag, '──────── REQUEST ────────');
    AppLog.d(_tag, '$methodLabel $fullUrl (multipart)');
    AppLog.d(_tag, 'baseUrl=$_baseUrl | endpoint=$path');
    AppLog.d(
      _tag,
      'requestBody={fields: $fields, files: ${files.map((f) => f.filename).toList()}}',
    );

    try {
      final streamed = await _http.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      _logResponse(fullUrl: fullUrl, response: response);
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

  Future<http.Response> _rawRequest({
    required HttpMethod method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
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

    final methodLabel = method.name.toUpperCase();
    final fullUrl = uri.toString();
    AppLog.d(_tag, '──────── REQUEST ────────');
    AppLog.d(_tag, '$methodLabel $fullUrl');
    AppLog.d(_tag, 'baseUrl=$_baseUrl | endpoint=$path');
    AppLog.d(
      _tag,
      'requestBody=${body == null ? '(none)' : _sanitizeForLog(body)}',
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
        case HttpMethod.delete:
          response = await _http
              .delete(uri, headers: headers, body: encoded)
              .timeout(effectiveTimeout);
      }

      _logResponse(fullUrl: fullUrl, response: response);
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

  void _logResponse({
    required String fullUrl,
    required http.Response response,
  }) {
    AppLog.d(_tag, '──────── RESPONSE ────────');
    AppLog.d(_tag, 'url=$fullUrl');
    AppLog.d(_tag, 'statusCode=${response.statusCode}');
    final body = response.body;
    if (body.isEmpty) {
      AppLog.d(_tag, 'responseBody=(empty)');
      return;
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        AppLog.d(_tag, 'responseBody=${_sanitizeForLog(decoded)}');
      } else if (decoded is List) {
        AppLog.d(_tag, 'responseBody=${jsonEncode(decoded)}');
      } else {
        AppLog.d(_tag, 'responseBody=$body');
      }
    } catch (_) {
      AppLog.d(_tag, 'responseBody=$body');
    }
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

  Map<String, dynamic>? _decodeOrThrow(http.Response response, String path) {
    if (response.statusCode == 204) {
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw CatalogApiException(
        statusCode: response.statusCode,
        code: 'UNEXPECTED_RESPONSE',
        message: 'Unexpected response format',
      );
    }

    throw _parseError(response);
  }

  CatalogApiException _parseError(http.Response response) {
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
      }
    } catch (_) {
      // Keep defaults when body is not catalog JSON.
    }

    AppLog.e(_tag, 'API error $code (${response.statusCode})');
    return CatalogApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      details: details,
      failedPhotos: failedPhotos,
      retryAfterSeconds: retryAfter,
    );
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
