import 'package:project_c/models/catalog/view_api_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class ViewsRequest {
  ViewsRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  /// POST `/views` — batch view beacon (1–50 items).
  Future<ViewBeaconResponse> recordViews(List<ViewBeaconItem> items) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.views,
      body: {
        'items': [for (final item in items) item.toJson()],
      },
      requiresAuth: true,
    );
    return ViewBeaconResponse.fromJson(json ?? const {});
  }
}
