import 'dart:io';

import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class ProfileRequest {
  ProfileRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<CatalogProfile> fetchMe() async {
    ProfileSwitchingLog.d(
      'PS-84',
      'GET ${Endpoints.me} omitProfileHeader=true',
    );
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.me,
      requiresAuth: true,
      omitProfileHeader: true,
    );
    return CatalogProfile.fromJson(json ?? const {});
  }

  /// Person + bootstrap in one recovery call (omit profile header).
  Future<({CatalogProfile profile, ProfileBootstrap? bootstrap})>
  fetchMeWithBootstrap() async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.me,
      requiresAuth: true,
      omitProfileHeader: true,
    );
    final map = json ?? const <String, dynamic>{};
    ProfileBootstrap? bootstrap;
    try {
      if (map['activeProfile'] is Map<String, dynamic> ||
          map['profiles'] is List) {
        bootstrap = ProfileBootstrap.fromJson(map);
      }
    } catch (_) {
      bootstrap = null;
    }
    return (
      profile: CatalogProfile.fromJson(map),
      bootstrap: bootstrap,
    );
  }

  Future<ProfileBootstrap> fetchProfiles() async {
    ProfileSwitchingLog.d(
      'PS-84',
      'GET ${Endpoints.meProfiles} omitProfileHeader=true',
    );
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.meProfiles,
      requiresAuth: true,
      omitProfileHeader: true,
    );
    return ProfileBootstrap.fromJson(json ?? const {});
  }

  Future<ProfileBootstrap> selectActiveProfile(String profileId) async {
    ProfileSwitchingLog.d(
      'PS-22/23/30/84',
      'PATCH ${Endpoints.meActiveProfile} profileId=$profileId '
      'omitProfileHeader=true',
    );
    final json = await _api.sendJson(
      method: HttpMethod.patch,
      path: Endpoints.meActiveProfile,
      body: {'profileId': profileId},
      requiresAuth: true,
      omitProfileHeader: true,
    );
    return ProfileBootstrap.fromJson(json ?? const {});
  }

  Future<List<PendingInvitation>> fetchMyInvitations() async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.meInvitations,
      requiresAuth: true,
      omitProfileHeader: true,
    );
    final items = json?['items'] as List? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PendingInvitation.fromJson)
        .toList();
  }

  Future<PendingInvitation> acceptInvitation(String invitationId) async {
    ProfileSwitchingLog.d(
      'PS-43/71/75',
      'POST accept invitation id=$invitationId',
    );
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.meInvitationAccept(invitationId),
      body: const <String, dynamic>{},
      requiresAuth: true,
      omitProfileHeader: true,
    );
    return PendingInvitation.fromJson(json ?? const {});
  }

  Future<PendingInvitation> declineInvitation(String invitationId) async {
    ProfileSwitchingLog.d('PS-44', 'POST decline invitation id=$invitationId');
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.meInvitationDecline(invitationId),
      body: const <String, dynamic>{},
      requiresAuth: true,
      omitProfileHeader: true,
    );
    return PendingInvitation.fromJson(json ?? const {});
  }

  Future<CatalogProfile> updateMe({
    required String firstName,
    String? lastName,
    File? profileImageFile,
  }) async {
    if (profileImageFile != null) {
      final fields = <String, String>{
        'firstName': firstName,
        'name': _fullName(firstName, lastName),
      };
      if (lastName != null && lastName.trim().isNotEmpty) {
        fields['lastName'] = lastName.trim();
      }
      final json = await _api.sendMultipart(
        method: HttpMethod.patch,
        path: Endpoints.me,
        fields: fields,
        files: [
          CatalogMultipartFile(
            field: 'profileImage',
            file: profileImageFile,
            filename: profileImageFile.uri.pathSegments.isNotEmpty
                ? profileImageFile.uri.pathSegments.last
                : 'avatar.jpg',
          ),
        ],
        requiresAuth: true,
      );
      return CatalogProfile.fromJson(json ?? const {});
    }

    final body = <String, dynamic>{'firstName': firstName};
    if (lastName != null) {
      body['lastName'] = lastName;
    }
    final json = await _api.sendJson(
      method: HttpMethod.patch,
      path: Endpoints.me,
      body: body,
      requiresAuth: true,
    );
    return CatalogProfile.fromJson(json ?? const {});
  }

  Future<({CatalogPhoto? profileImage, String? profileImageUrl})>
  uploadProfileImage(File file) async {
    final json = await _api.sendMultipart(
      method: HttpMethod.post,
      path: Endpoints.profileImage,
      fields: const {},
      files: [
        CatalogMultipartFile(
          field: 'profileImage',
          file: file,
          filename:
              file.uri.pathSegments.isNotEmpty
                  ? file.uri.pathSegments.last
                  : 'avatar.jpg',
        ),
      ],
      requiresAuth: true,
    );
    final raw = json?['profileImage'];
    return (
      profileImage:
          raw is Map<String, dynamic> ? CatalogPhoto.fromJson(raw) : null,
      profileImageUrl: json?['profileImageUrl'] as String?,
    );
  }

  Future<void> deleteProfileImage() async {
    await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.profileImage,
      requiresAuth: true,
    );
  }

  Future<CatalogProfile> skipStoreOnboarding({
    required String personalProfileId,
  }) async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.skipStore,
      body: const <String, dynamic>{},
      requiresAuth: true,
      profileIdOverride: personalProfileId,
    );
    return CatalogProfile.fromJson(json ?? const {});
  }

  /// Deletes the signed-in catalog account (`DELETE /me`).
  Future<void> deleteMe() async {
    await _api.sendJson(
      method: HttpMethod.delete,
      path: Endpoints.me,
      requiresAuth: true,
    );
  }

  String _fullName(String firstName, String? lastName) {
    final first = firstName.trim();
    final last = lastName?.trim() ?? '';
    if (last.isEmpty) return first;
    return '$first $last';
  }
}
