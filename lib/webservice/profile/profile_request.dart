import 'dart:io';

import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/resources/endpoints.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

class ProfileRequest {
  ProfileRequest({required CatalogApiClient apiClient}) : _api = apiClient;

  final CatalogApiClient _api;

  Future<CatalogProfile> fetchMe() async {
    final json = await _api.sendJson(
      method: HttpMethod.get,
      path: Endpoints.me,
      requiresAuth: true,
    );
    return CatalogProfile.fromJson(json ?? const {});
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

  Future<CatalogProfile> skipStoreOnboarding() async {
    final json = await _api.sendJson(
      method: HttpMethod.post,
      path: Endpoints.skipStore,
      body: const <String, dynamic>{},
      requiresAuth: true,
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
