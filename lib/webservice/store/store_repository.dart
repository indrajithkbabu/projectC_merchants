import 'dart:io';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_page.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/follow_api_models.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/services/store_home_prefetcher.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_request.dart';
import 'package:project_c/di/service_locator.dart';

abstract class StoreRepository {
  Future<CatalogPage<CatalogStore>> fetchHome({int limit = 20, String? cursor});

  Future<CatalogStore> fetchStore(String storeId);

  Future<SlugAvailability> checkSlugAvailability(String slug);

  Future<CatalogStore> createStore({
    required String name,
    required String slug,
    String? legalName,
    List<File> imageFiles = const [],
  });

  Future<CatalogStore> renameStore({
    required String storeId,
    required String name,
  });

  Future<CatalogStore> patchStorePrivacy({
    required String storeId,
    required StorePrivacyMode privacy,
  });

  Future<CatalogStore> patchStoreWastageMarkup({
    required String storeId,
    required double wastageMarkup,
  });

  Future<FollowActionResult> followStore(String storeId);

  Future<FollowActionResult> unfollowStore(String storeId);

  Future<bool> patchFollowNotifyUploads({
    required String storeId,
    required bool notifyUploads,
  });

  Future<FollowRequestPage> fetchFollowRequests({
    required String storeId,
    int limit = 20,
    String? cursor,
  });

  Future<void> acceptFollowRequest({
    required String storeId,
    required String followerUserId,
  });

  Future<void> rejectFollowRequest({
    required String storeId,
    required String followerUserId,
  });

  Future<FollowerListPage> fetchFollowers({
    required String storeId,
    int limit = 20,
    String? cursor,
  });

  Future<FollowingListPage> fetchFollowing({
    required String storeId,
    int limit = 20,
    String? cursor,
  });

  Future<void> removeFollower({
    required String storeId,
    required String followerUserId,
  });

  Future<CatalogStore> appendStoreImages({
    required String storeId,
    required List<File> imageFiles,
  });

  Future<CatalogStore> deleteStoreImage({
    required String storeId,
    required String imageId,
  });

  Future<CatalogStore> replaceStoreImages({
    required String storeId,
    required List<File> imageFiles,
  });

  Future<ContactBatchResult> addContacts({
    required String storeId,
    required List<String> phones,
  });

  Future<CatalogPage<StoreMember>> fetchMembers({
    required String storeId,
    int limit = 20,
    String? cursor,
  });

  Future<void> removeMember({
    required String storeId,
    required String userId,
  });

  Future<void> leaveStore(String storeId);
}

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl({
    required StoreRequest request,
    required CatalogSession session,
  }) : _request = request,
       _session = session;

  static const _tag = 'StoreRepository';

  final StoreRequest _request;
  final CatalogSession _session;

  @override
  Future<CatalogPage<CatalogStore>> fetchHome({
    int limit = 20,
    String? cursor,
  }) {
    AppLog.d(_tag, 'fetchHome cursor=$cursor');
    return _request.fetchHome(limit: limit, cursor: cursor);
  }

  @override
  Future<CatalogStore> fetchStore(String storeId) {
    return _request.fetchStore(storeId);
  }

  @override
  Future<SlugAvailability> checkSlugAvailability(String slug) {
    AppLog.d(_tag, 'checkSlugAvailability $slug');
    return _request.checkSlugAvailability(slug);
  }

  @override
  Future<CatalogStore> createStore({
    required String name,
    required String slug,
    String? legalName,
    List<File> imageFiles = const [],
  }) async {
    AppLog.d(_tag, 'createStore slug=$slug images=${imageFiles.length}');
    final store = await _request.createStore(
      name: name,
      slug: slug,
      legalName: legalName,
      imageFiles: imageFiles,
    );
    // Refresh profile so ownStore is current.
    try {
      await ServiceLocator.get<ProfileRepository>().fetchMe();
    } catch (e) {
      AppLog.e(_tag, 'Post-create fetchMe failed', e);
      if (_session.profile != null) {
        await _session.updateProfile(
          _session.profile!.copyWith(ownStore: store),
        );
      }
    }
    // Drop stale /home warm so Stores tab shows the new store without a
    // manual pull-to-refresh after create → team → listing.
    StoreHomePrefetcher.instance.invalidate();
    StoreHomePrefetcher.instance.prefetch();
    return store;
  }

  @override
  Future<CatalogStore> renameStore({
    required String storeId,
    required String name,
  }) {
    return _request.renameStore(storeId: storeId, name: name);
  }

  @override
  Future<CatalogStore> patchStorePrivacy({
    required String storeId,
    required StorePrivacyMode privacy,
  }) {
    AppLog.d(_tag, 'patchStorePrivacy store=$storeId privacy=${privacy.apiValue}');
    return _request.patchStorePrivacy(storeId: storeId, privacy: privacy);
  }

  @override
  Future<CatalogStore> patchStoreWastageMarkup({
    required String storeId,
    required double wastageMarkup,
  }) {
    AppLog.d(
      _tag,
      'patchStoreWastageMarkup store=$storeId wastage=$wastageMarkup',
    );
    return _request.patchStoreWastageMarkup(
      storeId: storeId,
      wastageMarkup: wastageMarkup,
    );
  }

  @override
  Future<FollowActionResult> followStore(String storeId) {
    AppLog.d(_tag, 'followStore store=$storeId');
    return _request.followStore(storeId);
  }

  @override
  Future<FollowActionResult> unfollowStore(String storeId) {
    AppLog.d(_tag, 'unfollowStore store=$storeId');
    return _request.unfollowStore(storeId);
  }

  @override
  Future<bool> patchFollowNotifyUploads({
    required String storeId,
    required bool notifyUploads,
  }) {
    AppLog.d(
      _tag,
      'patchFollowNotifyUploads store=$storeId notify=$notifyUploads',
    );
    return _request.patchFollowNotifyUploads(
      storeId: storeId,
      notifyUploads: notifyUploads,
    );
  }

  @override
  Future<FollowRequestPage> fetchFollowRequests({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) {
    return _request.fetchFollowRequests(
      storeId: storeId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<void> acceptFollowRequest({
    required String storeId,
    required String followerUserId,
  }) {
    AppLog.d(_tag, 'acceptFollowRequest store=$storeId user=$followerUserId');
    return _request.acceptFollowRequest(
      storeId: storeId,
      followerUserId: followerUserId,
    );
  }

  @override
  Future<void> rejectFollowRequest({
    required String storeId,
    required String followerUserId,
  }) {
    AppLog.d(_tag, 'rejectFollowRequest store=$storeId user=$followerUserId');
    return _request.rejectFollowRequest(
      storeId: storeId,
      followerUserId: followerUserId,
    );
  }

  @override
  Future<FollowerListPage> fetchFollowers({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) {
    return _request.fetchFollowers(
      storeId: storeId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<FollowingListPage> fetchFollowing({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) {
    return _request.fetchFollowing(
      storeId: storeId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<void> removeFollower({
    required String storeId,
    required String followerUserId,
  }) {
    AppLog.d(_tag, 'removeFollower store=$storeId user=$followerUserId');
    return _request.removeFollower(
      storeId: storeId,
      followerUserId: followerUserId,
    );
  }

  @override
  Future<CatalogStore> appendStoreImages({
    required String storeId,
    required List<File> imageFiles,
  }) {
    AppLog.d(_tag, 'appendStoreImages count=${imageFiles.length}');
    return _request.appendStoreImages(
      storeId: storeId,
      imageFiles: imageFiles,
    );
  }

  @override
  Future<CatalogStore> deleteStoreImage({
    required String storeId,
    required String imageId,
  }) {
    AppLog.d(_tag, 'deleteStoreImage id=$imageId');
    return _request.deleteStoreImage(storeId: storeId, imageId: imageId);
  }

  @override
  Future<CatalogStore> replaceStoreImages({
    required String storeId,
    required List<File> imageFiles,
  }) {
    AppLog.d(_tag, 'replaceStoreImages count=${imageFiles.length}');
    return _request.replaceStoreImages(
      storeId: storeId,
      imageFiles: imageFiles,
    );
  }

  @override
  Future<ContactBatchResult> addContacts({
    required String storeId,
    required List<String> phones,
  }) {
    AppLog.d(_tag, 'addContacts count=${phones.length}');
    return _request.addContacts(storeId: storeId, phones: phones);
  }

  @override
  Future<CatalogPage<StoreMember>> fetchMembers({
    required String storeId,
    int limit = 20,
    String? cursor,
  }) {
    return _request.fetchMembers(
      storeId: storeId,
      limit: limit,
      cursor: cursor,
    );
  }

  @override
  Future<void> removeMember({
    required String storeId,
    required String userId,
  }) {
    return _request.removeMember(storeId: storeId, userId: userId);
  }

  @override
  Future<void> leaveStore(String storeId) {
    return _request.leaveStore(storeId);
  }
}
