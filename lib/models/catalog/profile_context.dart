import 'package:equatable/equatable.dart';

/// Permission gates returned with the active profile / bootstrap.
class ProfilePermissions extends Equatable {
  const ProfilePermissions({
    this.browse = false,
    this.follow = false,
    this.wishlist = false,
    this.cart = false,
    this.createStore = false,
    this.upload = false,
    this.import = false,
    this.manageProducts = false,
    this.manageStore = false,
    this.manageMembers = false,
  });

  final bool browse;
  final bool follow;
  final bool wishlist;
  final bool cart;
  final bool createStore;
  final bool upload;
  final bool import;
  final bool manageProducts;
  final bool manageStore;
  final bool manageMembers;

  static const personalDefaults = ProfilePermissions(
    browse: true,
    follow: true,
    wishlist: true,
    cart: true,
    createStore: true,
  );

  factory ProfilePermissions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfilePermissions();
    bool flag(String key) => json[key] == true;
    return ProfilePermissions(
      browse: flag('browse'),
      follow: flag('follow'),
      wishlist: flag('wishlist'),
      cart: flag('cart'),
      createStore: flag('createStore'),
      upload: flag('upload'),
      import: flag('import'),
      manageProducts: flag('manageProducts'),
      manageStore: flag('manageStore'),
      manageMembers: flag('manageMembers'),
    );
  }

  Map<String, dynamic> toJson() => {
    'browse': browse,
    'follow': follow,
    'wishlist': wishlist,
    'cart': cart,
    'createStore': createStore,
    'upload': upload,
    'import': import,
    'manageProducts': manageProducts,
    'manageStore': manageStore,
    'manageMembers': manageMembers,
  };

  @override
  List<Object?> get props => [
    browse,
    follow,
    wishlist,
    cart,
    createStore,
    upload,
    import,
    manageProducts,
    manageStore,
    manageMembers,
  ];
}

enum ActableProfileType { user, store }

enum ActableProfileRole { personal, owner, staff }

/// One selectable (or pending) identity in the profile switcher.
class ActableProfile extends Equatable {
  const ActableProfile({
    required this.id,
    required this.type,
    required this.accountId,
    required this.name,
    required this.role,
    required this.permissions,
    this.slug,
    this.avatarUrl,
    this.logo,
    this.initials = '',
    this.label = '',
    this.status = 'active',
    this.selectable = true,
    this.unreadCount = 0,
  });

  /// e.g. `personal:<personId>` or `store:<storeId>`.
  final String id;
  final ActableProfileType type;
  final String accountId;
  final String name;
  final String? slug;
  final ActableProfileRole role;
  final ProfilePermissions permissions;
  final String? avatarUrl;
  final String? logo;
  final String initials;
  final String label;
  final String status;
  final bool selectable;

  /// UI-only until BE adds per-profile unread in bootstrap (see gaps MD).
  final int unreadCount;

  bool get isPersonal =>
      type == ActableProfileType.user || role == ActableProfileRole.personal;
  bool get isStore => type == ActableProfileType.store;
  bool get isOwner => role == ActableProfileRole.owner;
  bool get isStaff => role == ActableProfileRole.staff;

  String get effectiveAvatarUrl {
    final a = avatarUrl?.trim() ?? '';
    if (a.isNotEmpty) return a;
    return logo?.trim() ?? '';
  }

  String get displayInitials {
    final raw = initials.trim();
    if (raw.isNotEmpty) return raw.toUpperCase();
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.trim().isNotEmpty) {
      return name.trim().substring(0, name.trim().length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }

  /// Presentation subtitle for the switcher (Personal / Your store / Staff).
  String get roleLabel {
    final explicit = label.trim();
    if (explicit.isNotEmpty) return explicit;
    switch (role) {
      case ActableProfileRole.personal:
        return 'Personal';
      case ActableProfileRole.owner:
        return 'Your store';
      case ActableProfileRole.staff:
        return 'Staff';
    }
  }

  factory ActableProfile.fromJson(Map<String, dynamic> json) {
    final typeRaw = (json['type'] as String?)?.toLowerCase() ?? 'user';
    final roleRaw = (json['role'] as String?)?.toLowerCase() ?? 'personal';
    final unread =
        (json['unreadCount'] as num?)?.toInt() ??
        (json['unread'] as num?)?.toInt() ??
        0;
    return ActableProfile(
      id: json['id'] as String? ?? '',
      type:
          typeRaw == 'store'
              ? ActableProfileType.store
              : ActableProfileType.user,
      accountId: json['accountId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      role: switch (roleRaw) {
        'owner' => ActableProfileRole.owner,
        'staff' => ActableProfileRole.staff,
        _ => ActableProfileRole.personal,
      },
      permissions: ProfilePermissions.fromJson(
        json['permissions'] is Map<String, dynamic>
            ? json['permissions'] as Map<String, dynamic>
            : null,
      ),
      avatarUrl: json['avatarUrl'] as String?,
      logo: json['logo'] as String?,
      initials: json['initials'] as String? ?? '',
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      selectable: json['selectable'] != false,
      unreadCount: unread,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type == ActableProfileType.store ? 'store' : 'user',
    'accountId': accountId,
    'name': name,
    if (slug != null) 'slug': slug,
    'role': switch (role) {
      ActableProfileRole.personal => 'personal',
      ActableProfileRole.owner => 'owner',
      ActableProfileRole.staff => 'staff',
    },
    'permissions': permissions.toJson(),
    'avatarUrl': avatarUrl,
    'logo': logo,
    'initials': initials,
    'label': label,
    'status': status,
    'selectable': selectable,
    'unreadCount': unreadCount,
  };

  ActableProfile copyWith({
    String? id,
    ActableProfileType? type,
    String? accountId,
    String? name,
    String? slug,
    ActableProfileRole? role,
    ProfilePermissions? permissions,
    String? avatarUrl,
    String? logo,
    String? initials,
    String? label,
    String? status,
    bool? selectable,
    int? unreadCount,
  }) {
    return ActableProfile(
      id: id ?? this.id,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      logo: logo ?? this.logo,
      initials: initials ?? this.initials,
      label: label ?? this.label,
      status: status ?? this.status,
      selectable: selectable ?? this.selectable,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    accountId,
    name,
    slug,
    role,
    permissions,
    avatarUrl,
    logo,
    initials,
    label,
    status,
    selectable,
    unreadCount,
  ];
}

class InvitationSummary extends Equatable {
  const InvitationSummary({this.pendingCount = 0, this.hasPending = false});

  final int pendingCount;
  final bool hasPending;

  factory InvitationSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const InvitationSummary();
    final count = (json['pendingCount'] as num?)?.toInt() ?? 0;
    return InvitationSummary(
      pendingCount: count,
      hasPending: json['hasPending'] == true || count > 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'pendingCount': pendingCount,
    'hasPending': hasPending,
  };

  @override
  List<Object?> get props => [pendingCount, hasPending];
}

class StoreCreationQuota extends Equatable {
  const StoreCreationQuota({
    this.ownedStoreCount = 0,
    this.limit = 10,
    this.remainingSlots = 10,
    this.canCreate = true,
    this.requiresPersonalProfile = true,
  });

  final int ownedStoreCount;
  final int limit;
  final int remainingSlots;
  final bool canCreate;
  final bool requiresPersonalProfile;

  factory StoreCreationQuota.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StoreCreationQuota();
    return StoreCreationQuota(
      ownedStoreCount: (json['ownedStoreCount'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      remainingSlots: (json['remainingSlots'] as num?)?.toInt() ?? 10,
      canCreate: json['canCreate'] != false,
      requiresPersonalProfile: json['requiresPersonalProfile'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'ownedStoreCount': ownedStoreCount,
    'limit': limit,
    'remainingSlots': remainingSlots,
    'canCreate': canCreate,
    'requiresPersonalProfile': requiresPersonalProfile,
  };

  @override
  List<Object?> get props => [
    ownedStoreCount,
    limit,
    remainingSlots,
    canCreate,
    requiresPersonalProfile,
  ];
}

/// Pending staff invite row (not selectable until accepted).
class PendingInvitation extends Equatable {
  const PendingInvitation({
    required this.id,
    required this.storeId,
    required this.storeName,
    this.invitationId,
    this.name,
    this.slug,
    this.avatarUrl,
    this.initials = '',
    this.label = 'Invited',
    this.phone,
    this.status = 'pending',
    this.selectable = false,
    this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String? invitationId;
  final String storeId;
  final String storeName;
  final String? name;
  final String? slug;
  final String? avatarUrl;
  final String initials;
  final String label;
  final String? phone;
  final String status;
  final bool selectable;
  final String? createdAt;
  final String? decidedAt;

  String get decisionId =>
      (invitationId?.trim().isNotEmpty == true) ? invitationId!.trim() : id;

  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return storeName;
  }

  String get displayInitials {
    final raw = initials.trim();
    if (raw.isNotEmpty) return raw.toUpperCase();
    final source = displayName.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return source.substring(0, source.length.clamp(0, 2)).toUpperCase();
  }

  factory PendingInvitation.fromJson(Map<String, dynamic> json) {
    final storeName =
        json['storeName'] as String? ??
        json['name'] as String? ??
        '';
    return PendingInvitation(
      id: json['id'] as String? ?? json['invitationId'] as String? ?? '',
      invitationId: json['invitationId'] as String? ?? json['id'] as String?,
      storeId: json['storeId'] as String? ?? '',
      storeName: storeName,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      initials: json['initials'] as String? ?? '',
      label: json['label'] as String? ?? 'Invited',
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'pending',
      selectable: json['selectable'] == true,
      createdAt: json['createdAt'] as String?,
      decidedAt: json['decidedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invitationId': invitationId,
    'storeId': storeId,
    'storeName': storeName,
    'name': name,
    'slug': slug,
    'avatarUrl': avatarUrl,
    'initials': initials,
    'label': label,
    'phone': phone,
    'status': status,
    'selectable': selectable,
    'createdAt': createdAt,
    'decidedAt': decidedAt,
  };

  @override
  List<Object?> get props => [
    id,
    invitationId,
    storeId,
    storeName,
    name,
    slug,
    avatarUrl,
    initials,
    label,
    phone,
    status,
    selectable,
    createdAt,
    decidedAt,
  ];
}

/// Combined members + invitations row for `GET /stores/:id/staff`.
class StaffListRow extends Equatable {
  const StaffListRow({
    required this.id,
    required this.kind,
    required this.name,
    required this.role,
    required this.status,
    this.userId,
    this.invitationId,
    this.avatarUrl,
    this.initials = '',
    this.phone,
    this.isYou = false,
    this.canRemove = false,
  });

  final String id;
  /// `member` | `invitation`
  final String kind;
  final String? userId;
  final String? invitationId;
  final String name;
  final String? avatarUrl;
  final String initials;
  final String? phone;
  final String role;
  final String status;
  final bool isYou;
  final bool canRemove;

  bool get isInvitation => kind == 'invitation' || status == 'invited';
  bool get isOwner => role == 'owner';

  String get statusLabel {
    if (isOwner) return isYou ? 'Owner · You' : 'Owner';
    if (isInvitation || status == 'invited') return 'Invited';
    return 'Staff';
  }

  String get displayInitials {
    final raw = initials.trim();
    if (raw.isNotEmpty) return raw.toUpperCase();
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.trim().isNotEmpty) {
      return name.trim().substring(0, name.trim().length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }

  factory StaffListRow.fromJson(Map<String, dynamic> json) {
    return StaffListRow(
      id: json['id'] as String? ??
          json['userId'] as String? ??
          json['invitationId'] as String? ??
          '',
      kind: json['kind'] as String? ?? 'member',
      userId: json['userId'] as String?,
      invitationId: json['invitationId'] as String?,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      initials: json['initials'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'staff',
      status: json['status'] as String? ?? 'active',
      isYou: json['isYou'] == true,
      canRemove: json['canRemove'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    userId,
    invitationId,
    name,
    avatarUrl,
    initials,
    phone,
    role,
    status,
    isYou,
    canRemove,
  ];
}

/// Bootstrap payload shared by login, refresh, GET /me, GET /me/profiles, switch.
class ProfileBootstrap extends Equatable {
  const ProfileBootstrap({
    required this.activeProfile,
    required this.permissions,
    this.profiles = const [],
    this.pendingInvitations = const [],
    this.invitationSummary = const InvitationSummary(),
    this.storeCreation = const StoreCreationQuota(),
    this.profileContextVersion = 2,
    this.profileUiVersion = 1,
  });

  final ActableProfile activeProfile;
  final ProfilePermissions permissions;
  final List<ActableProfile> profiles;
  final List<PendingInvitation> pendingInvitations;
  final InvitationSummary invitationSummary;
  final StoreCreationQuota storeCreation;
  final int profileContextVersion;
  final int profileUiVersion;

  bool get canCreateStore =>
      storeCreation.canCreate &&
      (activeProfile.isPersonal
          ? permissions.createStore || storeCreation.canCreate
          : false);

  /// First owned store profile if any (legacy `ownStore` bridge).
  ActableProfile? get firstOwnedStore {
    for (final p in profiles) {
      if (p.isStore && p.isOwner) return p;
    }
    return null;
  }

  factory ProfileBootstrap.fromJson(Map<String, dynamic> json) {
    ActableProfile? active;
    final rawActive = json['activeProfile'];
    if (rawActive is Map<String, dynamic>) {
      active = ActableProfile.fromJson(rawActive);
    }

    final profiles = <ActableProfile>[];
    final rawProfiles = json['profiles'];
    if (rawProfiles is List) {
      for (final item in rawProfiles) {
        if (item is Map<String, dynamic>) {
          profiles.add(ActableProfile.fromJson(item));
        }
      }
    }

    active ??= profiles.isNotEmpty
        ? profiles.first
        : ActableProfile(
          id: '',
          type: ActableProfileType.user,
          accountId: '',
          name: '',
          role: ActableProfileRole.personal,
          permissions: ProfilePermissions.personalDefaults,
          label: 'Personal',
        );

    final pending = <PendingInvitation>[];
    final rawPending = json['pendingInvitations'];
    if (rawPending is List) {
      for (final item in rawPending) {
        if (item is Map<String, dynamic>) {
          pending.add(PendingInvitation.fromJson(item));
        }
      }
    }

    final permsRaw = json['permissions'];
    final permissions = ProfilePermissions.fromJson(
      permsRaw is Map<String, dynamic>
          ? permsRaw
          : active.permissions.toJson(),
    );

    return ProfileBootstrap(
      activeProfile: active.copyWith(permissions: permissions),
      permissions: permissions,
      profiles: profiles,
      pendingInvitations: pending,
      invitationSummary: InvitationSummary.fromJson(
        json['invitationSummary'] is Map<String, dynamic>
            ? json['invitationSummary'] as Map<String, dynamic>
            : null,
      ),
      storeCreation: StoreCreationQuota.fromJson(
        json['storeCreation'] is Map<String, dynamic>
            ? json['storeCreation'] as Map<String, dynamic>
            : null,
      ),
      profileContextVersion:
          (json['profileContextVersion'] as num?)?.toInt() ?? 2,
      profileUiVersion: (json['profileUiVersion'] as num?)?.toInt() ?? 1,
    );
  }

  /// Prefer root bootstrap fields; fall back to nested `user` object.
  factory ProfileBootstrap.fromAuthOrMe(Map<String, dynamic> json) {
    if (json['activeProfile'] is Map<String, dynamic> ||
        json['profiles'] is List) {
      return ProfileBootstrap.fromJson(json);
    }
    final user = json['user'];
    if (user is Map<String, dynamic>) {
      return ProfileBootstrap.fromJson(user);
    }
    return ProfileBootstrap.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'profileContextVersion': profileContextVersion,
    'profileUiVersion': profileUiVersion,
    'activeProfile': activeProfile.toJson(),
    'permissions': permissions.toJson(),
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'pendingInvitations':
        pendingInvitations.map((p) => p.toJson()).toList(),
    'invitationSummary': invitationSummary.toJson(),
    'storeCreation': storeCreation.toJson(),
  };

  ProfileBootstrap copyWith({
    ActableProfile? activeProfile,
    ProfilePermissions? permissions,
    List<ActableProfile>? profiles,
    List<PendingInvitation>? pendingInvitations,
    InvitationSummary? invitationSummary,
    StoreCreationQuota? storeCreation,
    int? profileContextVersion,
    int? profileUiVersion,
  }) {
    return ProfileBootstrap(
      activeProfile: activeProfile ?? this.activeProfile,
      permissions: permissions ?? this.permissions,
      profiles: profiles ?? this.profiles,
      pendingInvitations: pendingInvitations ?? this.pendingInvitations,
      invitationSummary: invitationSummary ?? this.invitationSummary,
      storeCreation: storeCreation ?? this.storeCreation,
      profileContextVersion:
          profileContextVersion ?? this.profileContextVersion,
      profileUiVersion: profileUiVersion ?? this.profileUiVersion,
    );
  }

  @override
  List<Object?> get props => [
    activeProfile,
    permissions,
    profiles,
    pendingInvitations,
    invitationSummary,
    storeCreation,
    profileContextVersion,
    profileUiVersion,
  ];
}
