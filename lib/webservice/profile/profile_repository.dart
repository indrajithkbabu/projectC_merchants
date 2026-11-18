import 'dart:io';

import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/profile/profile_request.dart';

abstract class ProfileRepository {
  /// Person + optional bootstrap. Concurrent callers share one in-flight GET.
  /// [force] true after mutations (image upload/delete) bypasses the short TTL.
  Future<CatalogProfile> fetchMe({bool force = false});

  /// Profile switcher bootstrap. Reuses a fresh / in-flight [fetchMe] bootstrap
  /// when present so cold start does not also hit `GET /me/profiles`.
  Future<ProfileBootstrap> fetchProfiles({bool force = false});

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

  /// Auth + AccountProfile both call /me on shell mount — share one request.
  static const _meReuseTtl = Duration(seconds: 5);

  final ProfileRequest _request;
  final CatalogSession _session;

  Future<CatalogProfile>? _inFlightMe;
  Future<ProfileBootstrap>? _inFlightProfiles;
  DateTime? _lastMeAt;

  /// Persist [profile] then return the session snapshot (UI source of truth).
  Future<CatalogProfile> _commit(CatalogProfile profile) async {
    await _session.updateProfile(profile);
    return _session.profile ?? profile;
  }

  Future<ProfileBootstrap> _commitBootstrap(ProfileBootstrap bootstrap) async {
    await _session.applyBootstrap(bootstrap);
    return _session.bootstrap ?? bootstrap;
  }

  bool _bootstrapReusable(ProfileBootstrap? boot) =>
      boot != null && boot.profiles.isNotEmpty;

  @override
  Future<CatalogProfile> fetchMe({bool force = false}) async {
    if (!force) {
      final inFlight = _inFlightMe;
      if (inFlight != null) return inFlight;
      final last = _lastMeAt;
      final cached = _session.profile;
      if (last != null &&
          cached != null &&
          DateTime.now().difference(last) < _meReuseTtl) {
        AppLog.d(_tag, 'fetchMe reuse session (TTL ${_meReuseTtl.inSeconds}s)');
        return cached;
      }
    }

    final future = _fetchMeNetwork();
    _inFlightMe = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightMe, future)) _inFlightMe = null;
    }
  }

  Future<CatalogProfile> _fetchMeNetwork() async {
    AppLog.d(_tag, 'fetchMe (with bootstrap when present)');
    final result = await _request.fetchMeWithBootstrap();
    if (result.bootstrap != null) {
      await _commitBootstrap(result.bootstrap!);
    }
    final committed = await _commit(result.profile);
    _lastMeAt = DateTime.now();
    return committed;
  }

  @override
  Future<ProfileBootstrap> fetchProfiles({bool force = false}) async {
    if (!force) {
      // Prefer sharing Auth/AccountProfile GET /me (same bootstrap payload).
      final me = _inFlightMe;
      if (me != null) {
        await me;
        final boot = _session.bootstrap;
        if (_bootstrapReusable(boot)) {
          AppLog.d(_tag, 'fetchProfiles reuse in-flight /me bootstrap');
          return boot!;
        }
      }
      final last = _lastMeAt;
      final boot = _session.bootstrap;
      if (last != null &&
          _bootstrapReusable(boot) &&
          DateTime.now().difference(last) < _meReuseTtl) {
        AppLog.d(_tag, 'fetchProfiles reuse recent /me bootstrap');
        return boot!;
      }
    }

    // One endpoint: /me already carries activeProfile + profiles + invites.
    await fetchMe(force: force);
    final fromMe = _session.bootstrap;
    if (_bootstrapReusable(fromMe)) {
      AppLog.d(_tag, 'fetchProfiles via /me bootstrap');
      return fromMe!;
    }

    // Legacy fallback when /me omits profiles[].
    final inFlight = _inFlightProfiles;
    if (inFlight != null) return inFlight;
    final future = _fetchProfilesNetwork();
    _inFlightProfiles = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightProfiles, future)) _inFlightProfiles = null;
    }
  }

  Future<ProfileBootstrap> _fetchProfilesNetwork() async {
    AppLog.d(_tag, 'fetchProfiles network GET /me/profiles');
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
      return await fetchMe(force: true);
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
      return await fetchMe(force: true);
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
