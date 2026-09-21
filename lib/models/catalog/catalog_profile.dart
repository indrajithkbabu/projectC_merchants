import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_store.dart';
import 'package:project_c/models/catalog/collection_models.dart';

enum CatalogOnboarding { nameRequired, storeOptional, complete }

CatalogOnboarding catalogOnboardingFromString(String? value) {
  switch (value) {
    case 'store_optional':
      return CatalogOnboarding.storeOptional;
    case 'complete':
      return CatalogOnboarding.complete;
    case 'name_required':
    default:
      return CatalogOnboarding.nameRequired;
  }
}

extension CatalogOnboardingX on CatalogOnboarding {
  String get apiValue {
    switch (this) {
      case CatalogOnboarding.nameRequired:
        return 'name_required';
      case CatalogOnboarding.storeOptional:
        return 'store_optional';
      case CatalogOnboarding.complete:
        return 'complete';
    }
  }
}

class CatalogProfile extends Equatable {
  const CatalogProfile({
    required this.id,
    required this.phone,
    required this.onboarding,
    this.firstName,
    this.lastName,
    this.ownStore,
    this.profileImage,
    this.profileImageUrl,
  });

  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;
  final CatalogOnboarding onboarding;
  final CatalogStore? ownStore;
  final CatalogPhoto? profileImage;
  final String? profileImageUrl;

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return phone;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  /// Prefer explicit URL, then nested image object.
  String get effectiveProfileImageUrl {
    final direct = profileImageUrl?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    return profileImage?.url.trim() ?? '';
  }

  factory CatalogProfile.fromJson(Map<String, dynamic> json) {
    final root =
        json['user'] is Map<String, dynamic>
            ? json['user'] as Map<String, dynamic>
            : json;
    final own = root['ownStore'] ?? root['stores'];
    CatalogStore? ownStore;
    if (own is Map<String, dynamic>) {
      ownStore = CatalogStore.fromJson(own);
    } else if (own is List && own.isNotEmpty && own.first is Map) {
      ownStore = CatalogStore.fromJson(
        Map<String, dynamic>.from(own.first as Map),
      );
    }

    var firstName = root['firstName'] as String?;
    var lastName = root['lastName'] as String?;
    final fullName = (root['name'] as String?)?.trim() ?? '';
    if ((firstName == null || firstName.trim().isEmpty) && fullName.isNotEmpty) {
      final parts = fullName.split(RegExp(r'\s+'));
      firstName = parts.first;
      if (parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    final rawImage = root['profileImage'];
    return CatalogProfile(
      id: root['id'] as String? ?? '',
      phone: root['phone'] as String? ?? '',
      firstName: firstName,
      lastName: lastName,
      onboarding: catalogOnboardingFromString(root['onboarding'] as String?),
      ownStore: ownStore,
      profileImage:
          rawImage is Map<String, dynamic>
              ? CatalogPhoto.fromJson(rawImage)
              : null,
      profileImageUrl: root['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'firstName': firstName,
    'lastName': lastName,
    'onboarding': onboarding.apiValue,
    'ownStore': ownStore?.toJson(),
    if (profileImage != null)
      'profileImage': {
        'id': profileImage!.id,
        'url': profileImage!.url,
        'width': profileImage!.width,
        'height': profileImage!.height,
      },
    'profileImageUrl': profileImageUrl,
  };

  CatalogProfile copyWith({
    String? id,
    String? phone,
    String? firstName,
    String? lastName,
    CatalogOnboarding? onboarding,
    CatalogStore? ownStore,
    CatalogPhoto? profileImage,
    String? profileImageUrl,
    bool clearOwnStore = false,
    bool clearProfileImage = false,
  }) {
    return CatalogProfile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      onboarding: onboarding ?? this.onboarding,
      ownStore: clearOwnStore ? null : (ownStore ?? this.ownStore),
      profileImage:
          clearProfileImage ? null : (profileImage ?? this.profileImage),
      profileImageUrl:
          clearProfileImage
              ? null
              : (profileImageUrl ?? this.profileImageUrl),
    );
  }

  @override
  List<Object?> get props => [
    id,
    phone,
    firstName,
    lastName,
    onboarding,
    ownStore,
    profileImage,
    profileImageUrl,
  ];
}
