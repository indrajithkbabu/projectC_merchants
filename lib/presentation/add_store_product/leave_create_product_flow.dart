import 'package:flutter/material.dart';
import 'package:project_c/data/merchant_store_session.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/jewel_upload_qa.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/session/catalog_session.dart';

/// Preview → group handoff when background upload already started.
///
/// Preview must [Navigator.pop] this (not call [leaveCreateProductFlow] itself)
/// so the group route can leave once — otherwise a compose-overlay auto-pop
/// can remove the store profile that leave just revealed.
const String kCreateProductBackgroundUpload = 'background_upload';

/// After create publish / background upload: land on Discover store profile
/// so [ProductUploadCoordinator] pending shimmer is visible.
///
/// Prefer popping back to an existing own-store [Routes.storeProfileRoute].
/// If that route is not on the stack, switch shell to My store and push
/// own-store profile for the shimmer.
void leaveCreateProductFlow(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final session = ServiceLocator.get<CatalogSession>();
  final own = session.profile?.ownStore;
  final storeId =
      (own?.id.trim().isNotEmpty == true)
          ? own!.id.trim()
          : (session.ownStoreId?.trim() ?? '');
  final storeName =
      (own?.name.trim().isNotEmpty == true)
          ? own!.name.trim()
          : (MerchantStoreSession.instance.storeName.trim().isNotEmpty
              ? MerchantStoreSession.instance.storeName.trim()
              : 'My store');
  final storeLink =
      (own?.storeLink.trim().isNotEmpty == true)
          ? own!.storeLink.trim()
          : MerchantStoreSession.instance.storeLink.trim();

  JewelUploadQa.step(
    'Leave create flow → store profile',
    detail: 'storeId=$storeId (expect pending shimmer)',
  );

  var landedOnStoreProfile = false;
  navigator.popUntil((route) {
    if (_isTargetStoreProfile(route, storeId)) {
      landedOnStoreProfile = true;
      return true;
    }
    return route.isFirst;
  });

  if (landedOnStoreProfile) {
    JewelUploadQa.log('  landed via popUntil storeProfile');
    return;
  }
  if (storeId.isEmpty) {
    JewelUploadQa.log('  skip push — no own storeId');
    return;
  }

  // Shell My store hosts a long-lived StoreProfileBloc (pending shimmer).
  ShellNav.request(ShellNavTab.myStore);

  // Shell home has no Discover store-profile route — open it for shimmer.
  JewelUploadQa.log('  pushNamed storeProfile + ShellNav.myStore');
  navigator.pushNamed(
    Routes.storeProfileRoute,
    arguments: <String, Object?>{
      'storeId': storeId,
      'storeName': storeName,
      'storeLink': storeLink,
      'isOwnStore': true,
    },
  );
}

bool _isTargetStoreProfile(Route<dynamic> route, String ownStoreId) {
  if (route.settings.name != Routes.storeProfileRoute) return false;
  if (ownStoreId.isEmpty) return true;

  final args = route.settings.arguments;
  if (args is! Map) return true;

  final argId = args['storeId'];
  if (argId is String && argId.trim().isNotEmpty) {
    return argId.trim() == ownStoreId;
  }

  final channel = args['store'];
  if (channel is StoreChannel) {
    final channelId = channel.id.trim();
    if (channelId.isNotEmpty) return channelId == ownStoreId;
    return channel.isOwn;
  }

  if (args['isOwnStore'] == true) return true;
  // Named store profile without a clear id — treat as match (legacy args).
  return true;
}
