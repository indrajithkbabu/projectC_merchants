import 'dart:io';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/profile/profile_request.dart';

abstract class ProfileRepository {
  Future<CatalogProfile> fetchMe();

  Future<CatalogProfile> updateNames({
    required String firstName,
    String? lastName,
    File? profileImageFile,
  });

  Future<CatalogProfile> uploadProfileImage(File file);

  Future<CatalogProfile> deleteProfileImage();

  Future<CatalogProfile> skipStoreOnboarding();

  /// Deletes the catalog account and clears the local session.
  Future<void> deleteAccount();
}

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required ProfileRequest request,
    required CatalogSession session,
  }) : _request = request,
       _session = session;

  static const _tag = 'ProfileRepository';

  final ProfileRequest _request;
  final CatalogSession _session;

  @override
  Future<CatalogProfile> fetchMe() async {
    AppLog.d(_tag, 'fetchMe');
    final profile = await _request.fetchMe();
    await _session.updateProfile(profile);
    return profile;
  }

  @override
  Future<CatalogProfile> updateNames({
    required String firstName,
    String? lastName,
    File? profileImageFile,
  }) async {
    AppLog.d(
      _tag,
      'updateNames hasImage=${profileImageFile != null}',
    );
    final profile = await _request.updateMe(
      firstName: firstName,
      lastName: lastName,
      profileImageFile: profileImageFile,
    );
    await _session.updateProfile(profile);
    return profile;
  }

  @override
  Future<CatalogProfile> uploadProfileImage(File file) async {
    AppLog.d(_tag, 'uploadProfileImage');
    final result = await _request.uploadProfileImage(file);
    final current = _session.profile ?? await _request.fetchMe();
    final updated = current.copyWith(
      profileImage: result.profileImage,
      profileImageUrl: result.profileImageUrl,
    );
    await _session.updateProfile(updated);
    return updated;
  }

  @override
  Future<CatalogProfile> deleteProfileImage() async {
    AppLog.d(_tag, 'deleteProfileImage');
    await _request.deleteProfileImage();
    final current = _session.profile ?? await _request.fetchMe();
    final updated = current.copyWith(clearProfileImage: true);
    await _session.updateProfile(updated);
    return updated;
  }

  @override
  Future<CatalogProfile> skipStoreOnboarding() async {
    AppLog.d(_tag, 'skipStoreOnboarding');
    final profile = await _request.skipStoreOnboarding();
    await _session.updateProfile(profile);
    return profile;
  }

  @override
  Future<void> deleteAccount() async {
    AppLog.d(_tag, 'deleteAccount');
    await _request.deleteMe();
    await _session.clear();
  }
}
