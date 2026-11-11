import 'package:project_c/helper/app_log.dart';

/// Debug traces for [docs/profile-switching-test-cases.md].
///
/// Filter logcat / Run console with: `@profile_switching`
class ProfileSwitchingLog {
  ProfileSwitchingLog._();

  static const tag = '@profile_switching';

  /// [caseId] e.g. `PS-01` or `PS-22/70` when one line covers several cases.
  static void d(String caseId, String message) {
    AppLog.d(tag, '$caseId $message');
  }

  static void e(String caseId, String message, [Object? error]) {
    AppLog.e(tag, '$caseId $message', error);
  }
}
