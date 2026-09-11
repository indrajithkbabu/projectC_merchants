import 'package:project_c/models/catalog/auth_models.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class AuthRequest {
  AuthRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<OtpChallenge> requestOtp({required String phone}) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.otpRequest,
      body: {'phone': phone},
      requiresAuth: false,
      skipAuthRetry: true,
    );
    return OtpChallenge.fromJson(json ?? const {});
  }

  Future<AuthSessionResult> verifyOtp({
    required String phone,
    required String challengeId,
    required String code,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.otpVerify,
      body: {
        'phone': phone,
        'challengeId': challengeId,
        'code': code,
      },
      requiresAuth: false,
      skipAuthRetry: true,
    );
    return AuthSessionResult.fromJson(json ?? const {});
  }

  Future<CatalogTokens> refreshToken({required String refreshToken}) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.refreshToken,
      body: {'refreshToken': refreshToken},
      requiresAuth: false,
      skipAuthRetry: true,
    );
    return CatalogTokens.fromJson(json ?? const {});
  }

  Future<void> logout({required String refreshToken}) async {
    await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.logout,
      body: {'refreshToken': refreshToken},
      requiresAuth: false,
      skipAuthRetry: true,
    );
  }
}
