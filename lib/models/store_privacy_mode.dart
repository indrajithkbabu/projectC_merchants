/// Store-wide visibility mode (no per-product privacy).
enum StorePrivacyMode { public, private }

extension StorePrivacyModeX on StorePrivacyMode {
  String get storageValue => name;

  /// Value sent/received on catalog privacy APIs (`public` | `private`).
  String get apiValue => name;

  String get label => switch (this) {
    StorePrivacyMode.public => 'Public',
    StorePrivacyMode.private => 'Private',
  };

  String get whoCanSeeSubtitle => switch (this) {
    StorePrivacyMode.public =>
      'Anyone on Jewel Flow can see your products and photos. '
          'They appear in search, trending and categories. '
          'Anyone can follow without asking.',
    StorePrivacyMode.private =>
      'Only followers you approve see your products and photos. '
          'Your store name and logo stay searchable so buyers can ask to follow.',
  };

  bool get isPrivate => this == StorePrivacyMode.private;

  static StorePrivacyMode fromStorage(String? raw) => fromApi(raw);

  static StorePrivacyMode fromApi(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    return StorePrivacyMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => StorePrivacyMode.public,
    );
  }

  String get pillLabel => switch (this) {
    StorePrivacyMode.public => 'Public store',
    StorePrivacyMode.private => 'Private store',
  };
}

/// Viewer follow relationship to a store (catalog `followStatus`).
enum StoreFollowStatus { none, pending, following, self, member }

StoreFollowStatus storeFollowStatusFromString(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'pending':
      return StoreFollowStatus.pending;
    case 'following':
    case 'active':
      return StoreFollowStatus.following;
    case 'self':
      return StoreFollowStatus.self;
    case 'member':
      return StoreFollowStatus.member;
    case 'none':
    default:
      return StoreFollowStatus.none;
  }
}

extension StoreFollowStatusX on StoreFollowStatus {
  String get apiValue => switch (this) {
    StoreFollowStatus.none => 'none',
    StoreFollowStatus.pending => 'pending',
    StoreFollowStatus.following => 'following',
    StoreFollowStatus.self => 'self',
    StoreFollowStatus.member => 'member',
  };

  bool get isFollowing =>
      this == StoreFollowStatus.following ||
      this == StoreFollowStatus.self ||
      this == StoreFollowStatus.member;

  bool get isPending => this == StoreFollowStatus.pending;
}
