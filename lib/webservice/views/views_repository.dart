import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/view_api_models.dart';
import 'package:project_c/webservice/views/views_request.dart';

abstract class ViewsRepository {
  Future<ViewBeaconResponse> recordViews(List<ViewBeaconItem> items);
}

class ViewsRepositoryImpl implements ViewsRepository {
  ViewsRepositoryImpl({required ViewsRequest request}) : _request = request;

  final ViewsRequest _request;
  static const _tag = 'ViewsRepository';

  @override
  Future<ViewBeaconResponse> recordViews(List<ViewBeaconItem> items) {
    AppLog.d(_tag, 'recordViews count=${items.length}');
    return _request.recordViews(items);
  }
}
