import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';
import 'package:project_c/models/catalog/profile_context.dart';
import 'package:project_c/storage/session_storage.dart';
import 'package:project_c/storage/store_home_cache.dart';
import 'package:project_c/storage/store_meta_cache.dart';
import 'package:project_c/storage/store_products_cache.dart';
import 'package:project_c/webservice/catalog_api_client.dart';

/// In-memory catalog session (person + active profile) backed by [SessionStorage].
class CatalogSession {
  CatalogSession({
    required SessionStorage storage,
    required CatalogApiClient apiClient,
  }) : _storage = storage,
       _apiClient = apiClient;

  static const _tag = 'CatalogSession';

  final SessionStorage _storage;
  final CatalogApiClient _apiClient;

  CatalogProfile? profile;
  CatalogTokens? tokens;
  ProfileBootstrap? bootstrap;

  bool get isSignedIn => tokens?.accessToken.isNotEmpty == true;

  /// Legacy bridge: first owned store id, or active store when owner.
  String? get ownStoreId {
    final active = bootstrap?.activeProfile;
    if (active != null && active.isStore && active.isOwner) {
      final id = active.accountId.trim();
      if (id.isNotEmpty) return id;
    }
    final fromList = bootstrap?.firstOwnedStore?.accountId.trim();
    if (fromList != null && fromList.isNotEmpty) return fromList;
    return profile?.ownStore?.id;
  }

  ActableProfile? get activeProfile => bootstrap?.activeProfile;

  String? get activeProfileId {
    final id = bootstrap?.activeProfile.id.trim();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  ProfilePermissions get permissions =>
      bootstrap?.permissions ??
      activeProfile?.permissions ??
      ProfilePermissions.personalDefaults;

  bool get isActingAsStore => activeProfile?.isStore == true;

  bool get isActingAsOwner => activeProfile?.isOwner == true;

  bool get isActingAsStaff => activeProfile?.isStaff == true;

  bool get isActingAsPersonal =>
      activeProfile == null || activeProfile!.isPersonal;

  /// Store id when active profile is a store; otherwise null.
  String? get activeStoreId {
    final active = activeProfile;
    if (active == null || !active.isStore) return null;
    final id = active.accountId.trim();
    return id.isEmpty ? null : id;
  }

  /// `personal:<userId>` for create-store / skip-store headers.
  String? get personalProfileId {
    final active = activeProfile;
    if (active != null && active.isPersonal && active.id.trim().isNotEmpty) {
      return active.id.trim();
    }
    final fromList = bootstrap?.profiles;
    if (fromList != null) {
      for (final p in fromList) {
        if (p.isPersonal && p.id.trim().isNotEmpty) return p.id.trim();
      }
    }
    final userId = profile?.id.trim() ?? '';
    if (userId.isEmpty) return null;
    return 'personal:$userId';
  }

  Future<void> restore() async {
    tokens = await _storage.readTokens();
    profile = await _storage.readProfile();
    bootstrap = await _storage.readBootstrap();
    // Disk → memory so My store / profile paint without cold shimmer after
    // process death (clear-data still has no files → true cold path).
    final cacheStoreId = activeStoreId ?? profile?.ownStore?.id.trim() ?? '';
    if (isSignedIn && cacheStoreId.isNotEmpty) {
      await Future.wait([
        StoreProductsCache.instance.read(cacheStoreId),
        StoreMetaCache.instance.read(cacheStoreId),
      ]);
    }
    AppLog.d(
      _tag,
      'Restored session signedIn=$isSignedIn '
      'onboarding=${profile?.onboarding} '
      'activeProfile=${activeProfileId ?? "(none)"}',
    );
    ProfileSwitchingLog.d(
      'PS-04/70',
      'session restore signedIn=$isSignedIn '
      'active=${activeProfileId ?? "(none)"} '
      'role=${activeProfile?.role.name ?? "(none)"}',
    );
  }

  Future<void> applyAuth({
    required CatalogProfile user,
    required CatalogTokens nextTokens,
    ProfileBootstrap? nextBootstrap,
  }) async {
    profile = user;
    tokens = nextTokens;
    if (nextBootstrap != null) {
      bootstrap = nextBootstrap;
    } else {
      bootstrap ??= _syntheticPersonalBootstrap(user);
    }
    _apiClient.bumpSessionEpoch();
    await _storage.saveTokens(nextTokens);
    await _storage.saveProfile(user);
    if (bootstrap != null) {
      await _storage.saveBootstrap(bootstrap!);
    }
    AppLog.d(
      _tag,
      'Auth applied user=${user.id} active=${activeProfileId ?? "(none)"}',
    );
    ProfileSwitchingLog.d(
      'PS-01/03/06',
      'auth applied user=${user.id} '
      'onboarding=${user.onboarding.name} '
      'active=${activeProfileId ?? "(none)"} '
      'personal=${isActingAsPersonal}',
    );
  }

  Future<void> updateProfile(CatalogProfile user) async {
    profile = user;
    await _storage.saveProfile(user);
  }

  Future<void> applyBootstrap(ProfileBootstrap next) async {
    bootstrap = next;
    await _storage.saveBootstrap(next);
    AppLog.d(_tag, 'Bootstrap applied active=${next.activeProfile.id}');
    ProfileSwitchingLog.d(
      'PS-04/22/23/70',
      'bootstrap applied active=${next.activeProfile.id} '
      'role=${next.activeProfile.role.name} '
      'profiles=${next.profiles.length} '
      'pendingInvites=${next.pendingInvitations.length} '
      'canCreate=${next.storeCreation.canCreate} '
      'owned=${next.storeCreation.ownedStoreCount}',
    );
  }

  Future<void> updateTokens(CatalogTokens nextTokens) async {
    tokens = nextTokens;
    await _storage.saveTokens(nextTokens);
  }

  Future<void> clear() async {
    profile = null;
    tokens = null;
    bootstrap = null;
    _apiClient.bumpSessionEpoch();
    await _storage.clear();
    // Drop store / image caches so the next account never sees prior data.
    await Future.wait([
      StoreHomeCache.instance.clearAll(),
      StoreProductsCache.instance.clearAll(),
      StoreMetaCache.instance.clearAll(),
      CatalogImageCache.clearAll(),
    ]);
    AppLog.d(_tag, 'Session cleared');
  }

  ProfileBootstrap _syntheticPersonalBootstrap(CatalogProfile user) {
    final personalId =
        user.id.trim().isEmpty ? '' : 'personal:${user.id.trim()}';
    final personal = ActableProfile(
      id: personalId,
      type: ActableProfileType.user,
      accountId: user.id,
      name: user.displayName,
      role: ActableProfileRole.personal,
      permissions: ProfilePermissions.personalDefaults,
      avatarUrl: user.effectiveProfileImageUrl.isEmpty
          ? null
          : user.effectiveProfileImageUrl,
      initials: _initialsFromProfile(user),
      label: 'Personal',
    );
    final profiles = <ActableProfile>[personal];
    final own = user.ownStore;
    if (own != null && own.id.trim().isNotEmpty) {
      profiles.add(
        ActableProfile(
          id: 'store:${own.id.trim()}',
          type: ActableProfileType.store,
          accountId: own.id.trim(),
          name: own.name,
          slug: own.slug,
          role: ActableProfileRole.owner,
          permissions: const ProfilePermissions(
            browse: true,
            follow: true,
            wishlist: true,
            cart: true,
            upload: true,
            import: true,
            manageProducts: true,
            manageStore: true,
            manageMembers: true,
          ),
          avatarUrl: own.coverImageUrl.trim().isEmpty
              ? null
              : own.coverImageUrl,
          initials: _initialsFromName(own.name),
          label: 'Your store',
        ),
      );
    }
    return ProfileBootstrap(
      activeProfile: personal,
      permissions: ProfilePermissions.personalDefaults,
      profiles: profiles,
      storeCreation: StoreCreationQuota(
        ownedStoreCount: own == null ? 0 : 1,
        remainingSlots: own == null ? 10 : 9,
        canCreate: true,
      ),
    );
  }

  String _initialsFromProfile(CatalogProfile user) {
    final first = user.firstName?.trim() ?? '';
    final last = user.lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    return _initialsFromName(user.displayName);
  }

  String _initialsFromName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.trim().isNotEmpty) {
      return name.trim().substring(0, name.trim().length.clamp(0, 2)).toUpperCase();
    }
    return '?';
  }
}
