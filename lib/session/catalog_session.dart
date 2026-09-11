import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

/// In-memory catalog session (profile + own store) backed by [SessionStorage].
class CatalogSession {
  CatalogSession({
    required SessionStorage storage,
    required CatalogApiClient apiClient,
  }) : _storage = storage,
       _apiClient = apiClient;

  static const _tag = 'CatalogSession';

  final SessionStorage _storage;
  final CatalogApiClient _apiClient;

  CatalogProfile? profile;
  CatalogTokens? tokens;

  bool get isSignedIn => tokens?.accessToken.isNotEmpty == true;
  String? get ownStoreId => profile?.ownStore?.id;

  Future<void> restore() async {
    tokens = await _storage.readTokens();
    profile = await _storage.readProfile();
    AppLog.d(
      _tag,
      'Restored session signedIn=$isSignedIn onboarding=${profile?.onboarding}',
    );
  }

  Future<void> applyAuth({
    required CatalogProfile user,
    required CatalogTokens nextTokens,
  }) async {
    profile = user;
    tokens = nextTokens;
    _apiClient.bumpSessionEpoch();
    await _storage.saveTokens(nextTokens);
    await _storage.saveProfile(user);
    AppLog.d(_tag, 'Auth applied user=${user.id}');
  }

  Future<void> updateProfile(CatalogProfile user) async {
    profile = user;
    await _storage.saveProfile(user);
  }

  Future<void> updateTokens(CatalogTokens nextTokens) async {
    tokens = nextTokens;
    await _storage.saveTokens(nextTokens);
  }

  Future<void> clear() async {
    profile = null;
    tokens = null;
    _apiClient.bumpSessionEpoch();
    await _storage.clear();
    AppLog.d(_tag, 'Session cleared');
  }
}
