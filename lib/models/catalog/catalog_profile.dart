import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_store.dart';

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
  });

  final String id;
  final String phone;
  final String? firstName;
  final String? lastName;
  final CatalogOnboarding onboarding;
  final CatalogStore? ownStore;

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) return phone;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  factory CatalogProfile.fromJson(Map<String, dynamic> json) {
    final own = json['ownStore'];
    return CatalogProfile(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      onboarding: catalogOnboardingFromString(json['onboarding'] as String?),
      ownStore:
          own is Map<String, dynamic> ? CatalogStore.fromJson(own) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'firstName': firstName,
    'lastName': lastName,
    'onboarding': onboarding.apiValue,
    'ownStore': ownStore?.toJson(),
  };

  CatalogProfile copyWith({
    String? id,
    String? phone,
    String? firstName,
    String? lastName,
    CatalogOnboarding? onboarding,
    CatalogStore? ownStore,
    bool clearOwnStore = false,
  }) {
    return CatalogProfile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      onboarding: onboarding ?? this.onboarding,
      ownStore: clearOwnStore ? null : (ownStore ?? this.ownStore),
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
  ];
}
