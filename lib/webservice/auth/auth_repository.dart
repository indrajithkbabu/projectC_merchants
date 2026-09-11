import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/auth_models.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/auth/auth_request.dart';
import 'package:project_c/webservice/catalog_api_client.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';

abstract class AuthRepository {
  Future<OtpChallenge> requestOtp({required String phone});

  Future<AuthSessionResult> verifyOtp({
    required String phone,
    required String challengeId,
    required String code,
  });

  Future<CatalogTokens> refreshTokens();

  Future<void> logout();

  Future<CatalogProfile?> restoreSession();
}

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRequest request,
    required CatalogSession session,
    required CatalogApiClient apiClient,
  }) : _request = request,
       _session = session,
       _apiClient = apiClient;

  static const _tag = 'AuthRepository';

  final AuthRequest _request;
  final CatalogSession _session;
  final CatalogApiClient _apiClient;

  @override
  Future<OtpChallenge> requestOtp({required String phone}) {
    AppLog.d(_tag, 'requestOtp');
    return _request.requestOtp(phone: phone);
  }

  @override
  Future<AuthSessionResult> verifyOtp({
    required String phone,
    required String challengeId,
    required String code,
  }) async {
    AppLog.d(_tag, 'verifyOtp');
    final result = await _request.verifyOtp(
      phone: phone,
      challengeId: challengeId,
      code: code,
    );
    await _session.applyAuth(user: result.user, nextTokens: result.tokens);
    return result;
  }

  @override
  Future<CatalogTokens> refreshTokens() async {
    final tokens = await _apiClient.refreshSession();
    await _session.updateTokens(tokens);
    return tokens;
  }

  @override
  Future<void> logout() async {
    final refresh = _session.tokens?.refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _request.logout(refreshToken: refresh);
      }
    } on CatalogApiException catch (e) {
      AppLog.e(_tag, 'Logout API failed (clearing locally anyway)', e);
    } catch (e) {
      AppLog.e(_tag, 'Logout failed (clearing locally anyway)', e);
    } finally {
      await _session.clear();
    }
  }

  @override
  Future<CatalogProfile?> restoreSession() async {
    await _session.restore();
    if (!_session.isSignedIn) return null;
    return _session.profile;
  }
}
