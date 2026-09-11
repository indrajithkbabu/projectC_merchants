import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class ProfileRequest {
  ProfileRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<CatalogProfile> fetchMe() async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.me,
      requiresAuth: true,
    );
    return CatalogProfile.fromJson(json ?? const {});
  }

  Future<CatalogProfile> updateMe({
    required String firstName,
    String? lastName,
  }) async {
    final body = <String, dynamic>{'firstName': firstName};
    if (lastName != null) {
      body['lastName'] = lastName;
    }
    final json = await _api.sendJson(
      method: HttpMethod.patch,
      path: Endpoints.me,
      body: body,
      requiresAuth: true,
    );
    return CatalogProfile.fromJson(json ?? const {});
  }

  Future<CatalogProfile> skipStoreOnboarding() async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.skipStore,
      body: const <String, dynamic>{},
      requiresAuth: true,
    );
    return CatalogProfile.fromJson(json ?? const {});
  }

  /// Deletes the signed-in catalog account (`DELETE /me`).
  Future<void> deleteMe() async {
    await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.me,
      requiresAuth: true,
    );
  }
}
