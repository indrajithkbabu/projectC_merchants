import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

/// HTTP for FCM device token register / unregister.
class DeviceTokenRequest {
  DeviceTokenRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// POST `/devices/token`
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.devicesToken,
      body: <String, dynamic>{
        'token': token,
        'platform': platform,
      },
      requiresAuth: true,
    );
  }

  /// DELETE `/devices/token`
  Future<void> unregisterToken({required String token}) async {
    await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.devicesToken,
      body: <String, dynamic>{'token': token},
      requiresAuth: true,
    );
  }
}
