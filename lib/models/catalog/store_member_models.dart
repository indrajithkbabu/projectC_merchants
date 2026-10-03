import 'package:equatable/equatable.dart';

class StoreMember extends Equatable {
  const StoreMember({
    required this.userId,
    required this.phone,
    required this.signedUp,
    this.firstName,
    this.lastName,
    this.localName,
    this.hasStore,
  });

  final String userId;
  final String phone;
  final String? firstName;
  final String? lastName;
  final bool signedUp;

  /// Device contact display name when catalog first/last are empty.
  final String? localName;

  /// Explicit “owns a store” from API when present (`hasStore` / `ownStoreId`).
  /// Null means the server did not send it — client may fall back to [signedUp].
  final bool? hasStore;

  /// Best available “created a store / on platform with store” signal without
  /// an extra API: prefer [hasStore], else [signedUp].
  bool get isStoreCreator => hasStore ?? signedUp;

  String get displayName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      if (last.isEmpty) return first;
      if (first.isEmpty) return last;
      return '$first $last';
    }
    final local = localName?.trim() ?? '';
    if (local.isNotEmpty) return local;
    return phone.trim().isEmpty ? 'Unknown' : phone.trim();
  }

  StoreMember copyWith({
    String? userId,
    String? phone,
    String? firstName,
    String? lastName,
    bool? signedUp,
    String? localName,
    bool? hasStore,
    bool clearHasStore = false,
  }) {
    return StoreMember(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      signedUp: signedUp ?? this.signedUp,
      localName: localName ?? this.localName,
      hasStore: clearHasStore ? null : (hasStore ?? this.hasStore),
    );
  }

  factory StoreMember.fromJson(Map<String, dynamic> json) {
    bool? hasStore;
    if (json.containsKey('hasStore')) {
      hasStore = json['hasStore'] as bool?;
    } else {
      final ownStoreId = json['ownStoreId'] ?? json['storeId'];
      if (ownStoreId is String && ownStoreId.trim().isNotEmpty) {
        hasStore = true;
      }
    }
    return StoreMember(
      userId: json['userId'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      signedUp: json['signedUp'] as bool? ?? false,
      hasStore: hasStore,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    phone,
    firstName,
    lastName,
    signedUp,
    localName,
    hasStore,
  ];
}

class ContactBatchResult extends Equatable {
  const ContactBatchResult({
    required this.added,
    required this.alreadyMembers,
  });

  final int added;
  final int alreadyMembers;

  factory ContactBatchResult.fromJson(Map<String, dynamic> json) {
    return ContactBatchResult(
      added: (json['added'] as num?)?.toInt() ?? 0,
      alreadyMembers: (json['alreadyMembers'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [added, alreadyMembers];
}

class SlugAvailability extends Equatable {
  const SlugAvailability({required this.slug, required this.available});

  final String slug;
  final bool available;

  factory SlugAvailability.fromJson(Map<String, dynamic> json) {
    return SlugAvailability(
      slug: json['slug'] as String? ?? '',
      available: json['available'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [slug, available];
}
