import 'package:project_c/helper/app_log.dart';
import 'package:project_c/webservice/notification/device_token_request.dart';

abstract class DeviceTokenRepository {
  Future<void> registerToken({
    required String token,
    required String platform,
  });

  Future<void> unregisterToken({required String token});
}

class DeviceTokenRepositoryImpl implements DeviceTokenRepository {
  DeviceTokenRepositoryImpl({required DeviceTokenRequest request})
    : _request = request;

  static const _tag = 'DeviceTokenRepository';

  final DeviceTokenRequest _request;

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    // ignore: avoid_print
    print(
      '[FCM_DEBUG] DeviceTokenRepository.register '
      'platform=$platform tokenLen=${token.length}',
    );
    AppLog.d(_tag, 'register platform=$platform');
    await _request.registerToken(token: token, platform: platform);
  }

  @override
  Future<void> unregisterToken({required String token}) async {
    // ignore: avoid_print
    print('[FCM_DEBUG] DeviceTokenRepository.unregister tokenLen=${token.length}');
    AppLog.d(_tag, 'unregister');
    await _request.unregisterToken(token: token);
  }
}
