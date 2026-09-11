import 'package:flutter/material.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/session/catalog_session.dart';

/// Opens the signed-in user's own store profile with a real catalog store id.
/// Falls back to the store listing when own-store metadata is unavailable.
void navigateToOwnStoreProfile(
  BuildContext context, {
  String? fallbackStoreId,
}) {
  final session = ServiceLocator.get<CatalogSession>();
  final own = session.profile?.ownStore;

  if (own != null && own.id.trim().isNotEmpty) {
    // Force isOwn even if /me omits relationship on ownStore.
    final channel = CatalogUiMapper.storeToChannel(own).copyWith(isOwn: true);
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.storeProfileRoute,
      (route) => false,
      arguments: <String, Object?>{
        'store': channel,
        'isOwnStore': true,
      },
    );
    return;
  }

  final id = fallbackStoreId?.trim() ?? '';
  if (id.isNotEmpty && id != 'my_store' && id != 'other_store') {
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.storeProfileRoute,
      (route) => false,
      arguments: <String, Object?>{
        'store': StoreChannel(
          id: id,
          name: 'Your Store',
          handle: id,
          avatarColor: 0xFF2AABEE,
          products: const [],
          isOwn: true,
        ),
        'storeId': id,
        'isOwnStore': true,
      },
    );
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil(
    Routes.storeListingRoute,
    (route) => false,
  );
}
