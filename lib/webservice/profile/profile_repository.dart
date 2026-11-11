import 'dart:io';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/profile/profile_request.dart';

abstract class ProfileRepository {
  Future<CatalogProfile> fetchMe();

  Future<ProfileBootstrap> fetchProfiles();

  Future<ProfileBootstrap> selectActiveProfile(String profileId);

  Future<PendingInvitation> acceptInvitation(String invitationId);

  Future<PendingInvitation> declineInvitation(String invitationId);

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

/// Cache-first: every successful API writes [CatalogSession], callers read cache.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required ProfileRequest request,
    required CatalogSession session,
  }) : _request = request,
       _session = session;

  static const _tag = 'ProfileRepository';

  final ProfileRequest _request;
  final CatalogSession _session;

  /// Persist [profile] then return the session snapshot (UI source of truth).
  Future<CatalogProfile> _commit(CatalogProfile profile) async {
    await _session.updateProfile(profile);
    return _session.profile ?? profile;
  }

  Future<ProfileBootstrap> _commitBootstrap(ProfileBootstrap bootstrap) async {
    await _session.applyBootstrap(bootstrap);
    return _session.bootstrap ?? bootstrap;
  }

  @override
  Future<CatalogProfile> fetchMe() async {
    AppLog.d(_tag, 'fetchMe (with bootstrap when present)');
    final result = await _request.fetchMeWithBootstrap();
    if (result.bootstrap != null) {
      await _commitBootstrap(result.bootstrap!);
    }
    return _commit(result.profile);
  }

  @override
  Future<ProfileBootstrap> fetchProfiles() async {
    AppLog.d(_tag, 'fetchProfiles');
    final bootstrap = await _request.fetchProfiles();
    return _commitBootstrap(bootstrap);
  }

  @override
  Future<ProfileBootstrap> selectActiveProfile(String profileId) async {
    AppLog.d(_tag, 'selectActiveProfile $profileId');
    final bootstrap = await _request.selectActiveProfile(profileId);
    return _commitBootstrap(bootstrap);
  }

  @override
  Future<PendingInvitation> acceptInvitation(String invitationId) async {
    AppLog.d(_tag, 'acceptInvitation $invitationId');
    return _request.acceptInvitation(invitationId);
  }

  @override
  Future<PendingInvitation> declineInvitation(String invitationId) async {
    AppLog.d(_tag, 'declineInvitation $invitationId');
    return _request.declineInvitation(invitationId);
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
    return _commit(profile);
  }

  @override
  Future<CatalogProfile> uploadProfileImage(File file) async {
    AppLog.d(_tag, 'uploadProfileImage');
    final result = await _request.uploadProfileImage(file);
    try {
      // Canonical GET after mutate → cache → return cache.
      return await fetchMe();
    } catch (e) {
      AppLog.e(_tag, 'POST image ok but GET /me failed; merging locally', e);
      final current = _session.profile;
      if (current == null) rethrow;
      return _commit(
        current.copyWith(
          profileImage: result.profileImage,
          profileImageUrl: result.profileImageUrl,
        ),
      );
    }
  }

  @override
  Future<CatalogProfile> deleteProfileImage() async {
    AppLog.d(_tag, 'deleteProfileImage');
    await _request.deleteProfileImage();
    try {
      return await fetchMe();
    } catch (e) {
      AppLog.e(_tag, 'DELETE image ok but GET /me failed; clearing locally', e);
      final current = _session.profile;
      if (current == null) rethrow;
      return _commit(current.copyWith(clearProfileImage: true));
    }
  }

  @override
  Future<CatalogProfile> skipStoreOnboarding() async {
    final personalId = _session.personalProfileId?.trim() ?? '';
    if (personalId.isEmpty) {
      throw StateError('Personal profile id required to skip store onboarding');
    }
    AppLog.d(_tag, 'skipStoreOnboarding personal=$personalId');
    final profile = await _request.skipStoreOnboarding(
      personalProfileId: personalId,
    );
    return _commit(profile);
  }

  @override
  Future<void> deleteAccount() async {
    AppLog.d(_tag, 'deleteAccount');
    await _request.deleteMe();
    await _session.clear();
  }
}
