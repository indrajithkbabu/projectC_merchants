import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, EdgeInsets, Padding, Theme;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/account_profile/account_profile_bloc.dart';
import 'package:project_c/bloc/add_store_product/add_store_product_bloc.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/bloc/import_requests/import_requests_bloc.dart';
import 'package:project_c/bloc/onboarding/onboarding_bloc.dart';
import 'package:project_c/bloc/product_details/product_details_bloc.dart';
import 'package:project_c/bloc/profile/profile_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/bloc/store_import/store_import_bloc.dart';
import 'package:project_c/bloc/store_listing/store_listing_bloc.dart';
import 'package:project_c/bloc/store_setup/store_setup_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/data/merchant_store_session.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/catalog_product_models.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/navigation/smooth_fade_page_route.dart';
import 'package:project_c/navigation/telegram_photo_page_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_compose_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_form_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_gallery_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_group_details_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_group_preview_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_group_route.dart';
import 'package:project_c/presentation/add_store_product/compose_product_draft.dart';
import 'package:project_c/presentation/add_store_product/edit_product_specs_route.dart';
import 'package:project_c/presentation/auth/country_picker_route.dart';
import 'package:project_c/presentation/auth/otp_route.dart';
import 'package:project_c/presentation/auth/phone_route.dart';
import 'package:project_c/presentation/home/home_placeholder_route.dart';
import 'package:project_c/presentation/bootstrap/bootstrap_route.dart';
import 'package:project_c/presentation/main_shell/invite_friends_route.dart';
import 'package:project_c/presentation/main_shell/main_shell_route.dart';
import 'package:project_c/presentation/main_shell/tabs/settings_tab.dart';
import 'package:project_c/presentation/onboarding/onboarding_route.dart';
import 'package:project_c/presentation/privacy/account_privacy_route.dart';
import 'package:project_c/presentation/privacy/activity_route.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/presentation/privacy/follow_requester_profile_route.dart';
import 'package:project_c/presentation/privacy/follow_requests_route.dart';
import 'package:project_c/presentation/privacy/followers_following_route.dart';
import 'package:project_c/presentation/product_details/product_details_route.dart';
import 'package:project_c/presentation/profile/profile_route.dart';
import 'package:project_c/presentation/search/global_search_route.dart';
import 'package:project_c/presentation/search/search_filters_route.dart';
import 'package:project_c/presentation/search/search_models.dart';
import 'package:project_c/presentation/search/store_search_route.dart';
import 'package:project_c/presentation/store_gallery/store_gallery_route.dart';
import 'package:project_c/presentation/store_import/store_import_approved_route.dart';
import 'package:project_c/presentation/store_import/store_import_pending_route.dart';
import 'package:project_c/presentation/store_import/store_import_requests_route.dart';
import 'package:project_c/presentation/store_import/store_import_select_route.dart';
import 'package:project_c/presentation/store_setup/store_setup_route.dart';
import 'package:project_c/presentation/storeprofile/collection_browse_route.dart';
import 'package:project_c/presentation/storeprofile/store_channel_route.dart';
import 'package:project_c/presentation/storeprofile/store_profile_route.dart';
import 'package:project_c/presentation/team/add_team_route.dart';

PageRoute? onGenerateRoutes(RouteSettings settings) {
  debugPrint('onGenerateRoutes called with route: ${settings.name}');
  switch (settings.name) {
    case Routes.bootstrapRoute:
      return _bootstrapRoute(settings);
    case Routes.onboardingRoute:
      return _onboardingRoute(settings);
    case Routes.authPhoneRoute:
      return _authPhoneRoute(settings);
    case Routes.authOtpRoute:
      return _authOtpRoute(settings);
    case Routes.profileSetupRoute:
      return _profileSetupRoute(settings);
    case Routes.storeSetupRoute:
      return _storeSetupRoute(settings);
    case Routes.addTeamRoute:
      return _addTeamRoute(settings);
    case Routes.storeListingRoute:
      return _storeListingRoute(settings);
    case Routes.storeProfileRoute:
      return _storeProfileRoute(settings);
    case Routes.storeChannelRoute:
      return _storeChannelRoute(settings);
    case Routes.storeGalleryRoute:
      return _storeGalleryRoute(settings);
    case Routes.storeImportSelectRoute:
      return _storeImportSelectRoute(settings);
    case Routes.storeImportPendingRoute:
      return _storeImportPendingRoute(settings);
    case Routes.storeImportApprovedRoute:
      return _storeImportApprovedRoute(settings);
    case Routes.storeImportRequestsRoute:
      return _storeImportRequestsRoute(settings);
    case Routes.addProductGalleryRoute:
      return _addProductGalleryRoute(settings);
    case Routes.addProductComposeRoute:
      return _addProductComposeRoute(settings);
    case Routes.addProductGroupRoute:
      return _addProductGroupRoute(settings);
    case Routes.addProductGroupDetailsRoute:
      return _addProductGroupDetailsRoute(settings);
    case Routes.addProductGroupPreviewRoute:
      return _addProductGroupPreviewRoute(settings);
    case Routes.addProductFormRoute:
      return _addProductFormRoute(settings);
    case Routes.editProductSpecsRoute:
      return _editProductSpecsRoute(settings);
    case Routes.collectionBrowseRoute:
      return _collectionBrowseRoute(settings);
    case Routes.productDetailsRoute:
      return _productDetailsRoute(settings);
    case Routes.globalSearchRoute:
      return _globalSearchRoute(settings);
    case Routes.storeSearchRoute:
      return _storeSearchRoute(settings);
    case Routes.searchFiltersRoute:
      return _searchFiltersRoute(settings);
    case Routes.countryPickerRoute:
      return _countryPickerRoute(settings);
    case Routes.inviteFriendsRoute:
      return _inviteFriendsRoute(settings);
    case Routes.settingsRoute:
      return _settingsRoute(settings);
    case Routes.activityRoute:
      return _activityRoute(settings);
    case Routes.accountPrivacyRoute:
      return _accountPrivacyRoute(settings);
    case Routes.followRequestsRoute:
      return _followRequestsRoute(settings);
    case Routes.followRequesterProfileRoute:
      return _followRequesterProfileRoute(settings);
    case Routes.followersFollowingRoute:
      return _followersFollowingRoute(settings);
    case Routes.homePlaceholderRoute:
      return _homePlaceholderRoute(settings);

    default:
      debugPrint('Route not found: ${settings.name}');
      return null;
  }
}

PageRoute? _bootstrapRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) => const BootstrapRoute(),
  );
}

PageRoute? _onboardingRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) {
      return BlocProvider(
        create: (_) => OnboardingBloc(),
        child: const OnboardingRoute(),
      );
    },
  );
}

PageRoute? _authPhoneRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) => const PhoneRoute(),
  );
}

PageRoute? _authOtpRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) => const OtpRoute(),
  );
}

PageRoute? _countryPickerRoute(RouteSettings settings) {
  final initialIso =
      settings.arguments is String ? settings.arguments as String : null;

  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) => CountryPickerRoute(initialIsoCode: initialIso),
  );
}

PageRoute? _profileSetupRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => ProfileBloc(),
          child: const ProfileRoute(),
        ),
  );
}

PageRoute? _storeSetupRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => StoreSetupBloc(),
          child: const StoreSetupRoute(),
        ),
  );
}

PageRoute? _addTeamRoute(RouteSettings settings) {
  final args = settings.arguments;
  final storeName =
      args is String
          ? args
          : (args is Map && args['storeName'] is String
              ? args['storeName'] as String
              : '');
  final returnToProfile =
      args is Map && args['returnToProfile'] == true;
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => TeamBloc(),
          child: AddTeamRoute(
            storeName: storeName,
            returnToProfile: returnToProfile,
          ),
        ),
  );
}

PageRoute? _inviteFriendsRoute(RouteSettings settings) {
  final args = settings.arguments;
  final existing =
      args is Map && args['contactsBloc'] is ContactsBloc
          ? args['contactsBloc'] as ContactsBloc
          : null;
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) {
      if (existing != null) {
        return BlocProvider<ContactsBloc>.value(
          value: existing,
          child: const InviteFriendsRoute(),
        );
      }
      return BlocProvider(
        create: (_) => ContactsBloc(),
        child: const InviteFriendsRoute(),
      );
    },
  );
}

PageRoute? _settingsRoute(RouteSettings settings) {
  final args = settings.arguments;
  final map = args is Map ? args : const <dynamic, dynamic>{};
  final existingBloc =
      map['accountProfileBloc'] is AccountProfileBloc
          ? map['accountProfileBloc'] as AccountProfileBloc
          : null;

  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) {
      final child = ScreenWrapper(
        backgroundColor: AppColors.background,
        child: const SettingsTab(showBack: true),
      );
      if (existingBloc != null) {
        return BlocProvider<AccountProfileBloc>.value(
          value: existingBloc,
          child: child,
        );
      }
      return BlocProvider(
        create: (_) => AccountProfileBloc(),
        child: child,
      );
    },
  );
}

PageRoute? _activityRoute(RouteSettings settings) {
  final args = settings.arguments;
  final map = args is Map ? args : const <dynamic, dynamic>{};
  final storeId =
      map['storeId'] is String ? (map['storeId'] as String).trim() : '';
  final storeName =
      map['storeName'] is String ? (map['storeName'] as String).trim() : '';
  if (storeId.isEmpty) return null;
  final pendingCount =
      map['pendingCount'] is int ? map['pendingCount'] as int : 0;
  final previewNames =
      map['previewNames'] is List
          ? (map['previewNames'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const <String>[];

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => ScreenWrapper(
          backgroundColor: AppColors.background,
          child: Padding(
            padding: EdgeInsets.only(
              top: ScreenWrapper.statusBarTop(context),
            ),
            child: ActivityRoute(
              storeId: storeId,
              storeName: storeName.isEmpty ? 'My store' : storeName,
              pendingCount: pendingCount,
              previewNames: previewNames,
              onBack: () => Navigator.of(context).maybePop(),
              onOpenRequests: () {
                Navigator.of(context).pushNamed(
                  Routes.followRequestsRoute,
                  arguments: {
                    'storeId': storeId,
                    'storeName':
                        storeName.isEmpty ? 'My store' : storeName,
                  },
                );
              },
            ),
          ),
        ),
  );
}

PageRoute? _accountPrivacyRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) => const AccountPrivacyRoute(),
  );
}

PageRoute? _followRequestsRoute(RouteSettings settings) {
  final args = settings.arguments;
  final map = args is Map ? args : const <dynamic, dynamic>{};
  final storeId =
      map['storeId'] is String ? (map['storeId'] as String).trim() : '';
  final storeName =
      map['storeName'] is String ? (map['storeName'] as String).trim() : '';
  if (storeId.isEmpty) return null;

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => FollowRequestsRoute(
          storeId: storeId,
          storeName: storeName,
        ),
  );
}

PageRoute? _followRequesterProfileRoute(RouteSettings settings) {
  final args = settings.arguments;
  if (args is! Map) return null;
  final requestRaw = args['request'];
  if (requestRaw is! Map) return null;
  final ownerStoreId =
      args['ownerStoreId'] is String
          ? (args['ownerStoreId'] as String).trim()
          : '';
  final ownerStoreName =
      args['ownerStoreName'] is String
          ? (args['ownerStoreName'] as String).trim()
          : '';
  if (ownerStoreId.isEmpty) return null;
  final readOnly = args['readOnly'] == true;

  final request = followRequestItemFromMap(requestRaw);

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => FollowRequesterProfileRoute(
          request: request,
          ownerStoreId: ownerStoreId,
          ownerStoreName: ownerStoreName,
          readOnly: readOnly,
        ),
  );
}

PageRoute? _followersFollowingRoute(RouteSettings settings) {
  final args = settings.arguments;
  if (args is! Map) return null;
  final storeId =
      args['storeId'] is String ? (args['storeId'] as String).trim() : '';
  if (storeId.isEmpty) return null;
  final storeName =
      args['storeName'] is String
          ? (args['storeName'] as String).trim()
          : 'Store';
  final initialTabRaw =
      args['initialTab'] is String
          ? (args['initialTab'] as String).trim().toLowerCase()
          : 'followers';
  final initialTab =
      initialTabRaw == 'following'
          ? FollowersFollowingTab.following
          : FollowersFollowingTab.followers;
  final followerCount =
      args['followerCount'] is num
          ? (args['followerCount'] as num).toInt()
          : 0;
  final followingCount =
      args['followingCount'] is num
          ? (args['followingCount'] as num).toInt()
          : 0;

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => FollowersFollowingRoute(
          storeId: storeId,
          storeName: storeName.isEmpty ? 'Store' : storeName,
          initialTab: initialTab,
          followerCount: followerCount,
          followingCount: followingCount,
        ),
  );
}

PageRoute? _storeListingRoute(RouteSettings settings) {
  final args = settings.arguments;
  if (args is Map) {
    final storeName = args['storeName'];
    if (storeName is String && storeName.trim().isNotEmpty) {
      MerchantStoreSession.instance.bootstrap(
        storeName: storeName,
        members: _asTeamMembers(args['members']),
      );
    }
  }

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => StoreListingBloc()),
            BlocProvider(create: (_) => ContactsBloc()),
            BlocProvider(create: (_) => AccountProfileBloc()),
          ],
          child: const MainShellRoute(),
        ),
  );
}

PageRoute? _storeProfileRoute(RouteSettings settings) {
  final args = settings.arguments;
  final session = MerchantStoreSession.instance;

  StoreChannel? channel;
  if (args is Map && args['store'] is StoreChannel) {
    channel = args['store'] as StoreChannel;
  }

  final bool isOwnStore;
  if (channel != null) {
    isOwnStore = channel.isOwn;
  } else if (args is Map && args['isOwnStore'] is bool) {
    isOwnStore = args['isOwnStore'] as bool;
  } else {
    isOwnStore = true;
  }

  final storeName =
      channel?.name ??
      (args is Map && args['storeName'] is String
          ? args['storeName'] as String
          : session.storeName);
  final storeLink =
      channel?.storeLink ??
      (args is Map && args['storeLink'] is String
          ? args['storeLink'] as String
          : session.storeLink);
  final storeId =
      channel?.id ??
      (args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : 'my_store');
  final avatarColor = channel?.avatarColor ?? 0xFF2AABEE;
  final members =
      args is Map
          ? _asTeamMembers(args['members'])
          : (isOwnStore ? session.members : const <TeamMember>[]);
  final products =
      channel != null
          ? (isOwnStore
              ? List<StoreProduct>.from(session.products)
              : List<StoreProduct>.from(channel.products))
          : (args is Map && args['products'] != null
              ? _asProducts(args['products'])
              : (isOwnStore
                  ? List<StoreProduct>.from(session.products)
                  : const <StoreProduct>[]));
  final focusProductId =
      args is Map && args['focusProductId'] is String
          ? (args['focusProductId'] as String).trim()
          : '';

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => StoreProfileBloc(
                storeName: storeName,
                members: members.isEmpty && isOwnStore ? session.members : members,
                products: products,
                isOwnStore: isOwnStore,
                storeId: storeId,
                storeLink: storeLink,
                coverImageUrl: channel?.coverImageUrl,
                avatarColor: avatarColor,
              ),
          child: StoreProfileRoute(
            focusProductId: focusProductId.isEmpty ? null : focusProductId,
          ),
        ),
  );
}

PageRoute? _storeChannelRoute(RouteSettings settings) {
  final args = settings.arguments;
  if (args is! Map) return null;
  final storeId = args['storeId'] is String ? args['storeId'] as String : '';
  final storeName =
      args['storeName'] is String ? args['storeName'] as String : 'Store';
  final storeLink =
      args['storeLink'] is String ? args['storeLink'] as String : '';
  final imageUrls =
      args['imageUrls'] is List
          ? (args['imageUrls'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
  final products =
      args['products'] != null
          ? _asProducts(args['products'])
          : const <StoreProduct>[];
  final followerCount =
      args['followerCount'] is int ? args['followerCount'] as int : 0;
  final followingCount =
      args['followingCount'] is int ? args['followingCount'] as int : 0;
  final productCount =
      args['productCount'] is int ? args['productCount'] as int : 0;
  final isOwnStore =
      args['isOwnStore'] is bool ? args['isOwnStore'] as bool : false;
  final profileBloc =
      args['profileBloc'] is StoreProfileBloc
          ? args['profileBloc'] as StoreProfileBloc
          : null;

  final enableFollowChrome = !isOwnStore && profileBloc != null;
  final page = StoreChannelRoute(
    storeId: storeId,
    storeName: storeName,
    storeLink: storeLink,
    imageUrls: imageUrls,
    products: products,
    followerCount: followerCount,
    followingCount: followingCount,
    productCount: productCount,
    isOwnStore: isOwnStore,
    enableFollowChrome: enableFollowChrome,
  );

  // Expand from Discover header (fade + soft rise) — not a Cupertino slide.
  return StoreChannelRevealRoute<void>(
    settings: settings,
    builder:
        (context) =>
            profileBloc == null
                ? page
                : BlocProvider<StoreProfileBloc>.value(
                  value: profileBloc,
                  child: page,
                ),
  );
}

PageRoute? _storeGalleryRoute(RouteSettings settings) {
  final args = settings.arguments;
  final session = MerchantStoreSession.instance;
  final products =
      args is Map && args['products'] != null
          ? _asProducts(args['products'])
          : List<StoreProduct>.from(session.products);
  final storeName =
      args is Map && args['storeName'] is String
          ? args['storeName'] as String
          : session.storeName;
  final storeLink =
      args is Map && args['storeLink'] is String
          ? args['storeLink'] as String
          : session.storeLink;
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : null;
  final isOwnStore =
      args is Map && args['isOwnStore'] is bool
          ? args['isOwnStore'] as bool
          : false;
  final focusProductId =
      args is Map && args['focusProductId'] is String
          ? (args['focusProductId'] as String).trim()
          : '';

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => StoreGalleryBloc(
                products: products,
                storeName: storeName,
                storeLink: storeLink,
                storeId: storeId,
                isOwnStore: isOwnStore,
              ),
          child: StoreGalleryRoute(
            focusProductId: focusProductId.isEmpty ? null : focusProductId,
          ),
        ),
  );
}

PageRoute? _storeImportSelectRoute(RouteSettings settings) {
  final store = _storeChannelFromArgs(settings.arguments);
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => StoreImportBloc(sourceStore: store),
          child: const StoreImportSelectRoute(),
        ),
  );
}

PageRoute? _storeImportPendingRoute(RouteSettings settings) {
  final store = _storeChannelFromArgs(settings.arguments);
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => StoreImportBloc(sourceStore: store),
          child: const StoreImportPendingRoute(),
        ),
  );
}

PageRoute? _storeImportApprovedRoute(RouteSettings settings) {
  final store = _storeChannelFromArgs(settings.arguments);
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => StoreImportBloc(sourceStore: store),
          child: const StoreImportApprovedRoute(),
        ),
  );
}

PageRoute? _storeImportRequestsRoute(RouteSettings settings) {
  final args = settings.arguments;
  final storeId =
      args is Map && args['storeId'] is String ? args['storeId'] as String : '';
  final storeName =
      args is Map && args['storeName'] is String
          ? args['storeName'] as String
          : 'Your Store';
  final initialTab =
      args is Map && args['initialTab'] == 1 ? 1 : 0;
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => ImportRequestsBloc(
                storeId: storeId,
                storeName: storeName,
              ),
          child: StoreImportRequestsRoute(initialTab: initialTab),
        ),
  );
}

StoreChannel _storeChannelFromArgs(Object? args) {
  if (args is Map) {
    final products = _asProducts(args['products']);
    final storeLink =
        args['storeLink'] is String ? args['storeLink'] as String : '';
    final handle =
        storeLink.isNotEmpty
            ? storeLink.replaceAll('.jewelflow.app', '')
            : 'store';
    return StoreChannel(
      id: args['storeId'] is String ? args['storeId'] as String : 'other_store',
      name: args['storeName'] is String ? args['storeName'] as String : 'Store',
      handle: handle,
      avatarColor:
          args['avatarColor'] is int ? args['avatarColor'] as int : 0xFF8E44AD,
      products: products,
    );
  }
  return StoreChannel.dummyOtherStores().first;
}

List<TeamMember> _asTeamMembers(Object? value) {
  if (value is List<TeamMember>) return value;
  if (value is List) return value.whereType<TeamMember>().toList();
  return const [];
}

List<StoreProduct> _asProducts(Object? value) {
  if (value is List<StoreProduct>) return value;
  if (value is List) return value.whereType<StoreProduct>().toList();
  return const [];
}

PageRoute? _addProductGalleryRoute(RouteSettings settings) {
  final args = settings.arguments;
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : null;
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create: (_) => AddStoreProductBloc(storeId: storeId),
          child: const AddProductGalleryRoute(),
        ),
  );
}

PageRoute? _addProductComposeRoute(RouteSettings settings) {
  final args = settings.arguments;
  final imagePaths =
      args is Map && args['imagePaths'] is List
          ? (args['imagePaths'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : null;
  final initialIndex =
      args is Map && args['initialIndex'] is int
          ? args['initialIndex'] as int
          : 0;
  final initialDrafts =
      args is Map && args['initialDrafts'] is List
          ? (args['initialDrafts'] as List)
              .whereType<ComposePhotoDraft>()
              .toList(growable: false)
          : const <ComposePhotoDraft>[];
  final itemIds =
      args is Map && args['itemIds'] is List
          ? (args['itemIds'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
  final returnResult = args is Map && args['returnResult'] == true;
  final allowAddDelete =
      args is Map ? args['allowAddDelete'] != false : true;
  final importMode = args is Map && args['importMode'] == true;
  final sourceStoreId =
      args is Map && args['sourceStoreId'] is String
          ? (args['sourceStoreId'] as String).trim()
          : '';
  final sourceStoreName =
      args is Map && args['sourceStoreName'] is String
          ? (args['sourceStoreName'] as String).trim()
          : '';
  final sourceProductIds =
      args is Map && args['sourceProductIds'] is List
          ? (args['sourceProductIds'] as List)
              .whereType<String>()
              .map((e) => e.trim())
              .toList(growable: false)
          : const <String>[];
  final sourceLocked =
      args is Map && args['sourceLocked'] is List
          ? (args['sourceLocked'] as List).map((e) => e == true).toList(
            growable: false,
          )
          : const <bool>[];
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => AddProductComposeRoute(
          imagePaths: imagePaths,
          storeId: storeId,
          initialIndex: initialIndex,
          initialDrafts: initialDrafts,
          itemIds: itemIds,
          returnResult: returnResult,
          allowAddDelete: allowAddDelete,
          importMode: importMode,
          sourceStoreId: sourceStoreId,
          sourceStoreName: sourceStoreName,
          sourceProductIds: sourceProductIds,
          sourceLocked: sourceLocked,
        ),
  );
}

PageRoute? _addProductGroupRoute(RouteSettings settings) {
  final args = settings.arguments;
  final selectedItems =
      args is Map && args['selectedItems'] is List
          ? (args['selectedItems'] as List)
              .whereType<GalleryImageItem>()
              .toList()
          : <GalleryImageItem>[];
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : null;
  final initialTitle =
      args is Map && args['initialTitle'] is String
          ? (args['initialTitle'] as String).trim()
          : '';
  final initialTags =
      args is Map && args['tags'] is List
          ? (args['tags'] as List)
              .whereType<String>()
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
  final composeOverlay = args is Map && args['composeOverlay'] == true;
  final ProductSpec? composeSpec =
      args is Map && args['groupSpec'] is ProductSpec
          ? args['groupSpec'] as ProductSpec
          : null;
  final composeStockStatus =
      args is Map && args['stockStatus'] is String
          ? (args['stockStatus'] as String).trim()
          : '';
  final composeMtoDays =
      args is Map && args['mtoDays'] is int
          ? args['mtoDays'] as int
          : (args is Map && args['mtoDays'] is num
              ? (args['mtoDays'] as num).toInt()
              : null);
  final composeIsLocked = args is Map && args['isLocked'] == true;
  final composeApplyToAll = args is Map && args['applyToAll'] != false;
  final photoDrafts =
      args is Map && args['photoDrafts'] is List
          ? (args['photoDrafts'] as List).whereType<ComposePhotoDraft>().toList()
          : const <ComposePhotoDraft>[];
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => BulkUploadBloc(
                images: selectedItems,
                storeId: storeId,
                initialTitle: initialTitle.isEmpty ? null : initialTitle,
                initialTags: initialTags,
                initialItemSpecs:
                    photoDrafts.isEmpty
                        ? null
                        : [for (final d in photoDrafts) d.spec],
              ),
          child: AddProductGroupRoute(
            composeOverlay: composeOverlay,
            composeSpec: composeSpec,
            composeStockStatus: composeStockStatus,
            composeMtoDays: composeMtoDays,
            composeIsLocked: composeIsLocked,
            composeApplyToAll: composeApplyToAll,
            composeDrafts: photoDrafts,
          ),
        ),
  );
}

PageRoute? _addProductGroupDetailsRoute(RouteSettings settings) {
  final bloc = _bulkUploadBlocFromArgs(settings.arguments);
  if (bloc == null) {
    debugPrint('add_product_group_details_route missing BulkUploadBloc');
    return null;
  }
  final args = settings.arguments;
  final scope =
      args is Map && args['scope'] is BulkSpecScope
          ? args['scope'] as BulkSpecScope
          : BulkSpecScope.group;
  final itemId =
      args is Map && args['itemId'] is String ? args['itemId'] as String : null;
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider.value(
          value: bloc,
          child: AddProductGroupDetailsRoute(scope: scope, itemId: itemId),
        ),
  );
}

PageRoute? _addProductGroupPreviewRoute(RouteSettings settings) {
  final bloc = _bulkUploadBlocFromArgs(settings.arguments);
  if (bloc == null) {
    debugPrint('add_product_group_preview_route missing BulkUploadBloc');
    return null;
  }
  final args = settings.arguments;
  final autoOpenEdit = args is Map && args['autoOpenEdit'] == true;
  final stockStatus =
      args is Map && args['stockStatus'] is String
          ? (args['stockStatus'] as String).trim()
          : 'in';
  final mtoDays =
      args is Map && args['mtoDays'] is int
          ? args['mtoDays'] as int
          : (args is Map && args['mtoDays'] is num
              ? (args['mtoDays'] as num).toInt()
              : null);
  final isLocked = args is Map && args['isLocked'] == true;
  final photoRows =
      args is Map && args['photoRows'] is List
          ? (args['photoRows'] as List).whereType<TitleOnlyPhotoRow>().toList()
          : const <TitleOnlyPhotoRow>[];
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider.value(
          value: bloc,
          child: AddProductGroupPreviewRoute(
            autoOpenEdit: autoOpenEdit,
            stockStatus: stockStatus.isEmpty ? 'in' : stockStatus,
            mtoDays: mtoDays,
            isLocked: isLocked,
            photoRows: photoRows,
          ),
        ),
  );
}

BulkUploadBloc? _bulkUploadBlocFromArgs(Object? args) {
  if (args is Map && args['bloc'] is BulkUploadBloc) {
    return args['bloc'] as BulkUploadBloc;
  }
  return null;
}

PageRoute? _addProductFormRoute(RouteSettings settings) {
  final args = settings.arguments;
  final selectedItems =
      args is Map && args['selectedItems'] is List
          ? (args['selectedItems'] as List).whereType<GalleryImageItem>().toList()
          : <GalleryImageItem>[];
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : null;
  final isEditMode =
      args is Map && args['mode'] is String && args['mode'] == 'edit';
  final listingId =
      args is Map && args['listingId'] is String
          ? args['listingId'] as String
          : null;
  final revision =
      args is Map && args['revision'] is int ? args['revision'] as int : 1;
  final title =
      args is Map && args['title'] is String ? args['title'] as String : '';
  final description =
      args is Map && args['description'] is String
          ? args['description'] as String
          : '';
  final tags =
      args is Map && args['tags'] is List
          ? (args['tags'] as List)
              .map((e) => e.toString().trim().toLowerCase())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];
  final imagePaths =
      args is Map && args['imagePaths'] is List
          ? (args['imagePaths'] as List)
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
          : <String>[];
  final photoAssetIds =
      args is Map && args['photoAssetIds'] is List
          ? (args['photoAssetIds'] as List)
              .map((e) => e.toString().trim())
              .toList()
          : <String>[];

  final editGalleryItems = <GalleryImageItem>[
    for (var i = 0; i < imagePaths.length; i++)
      GalleryImageItem(
        id: 'existing_$i',
        filePath: imagePaths[i],
        assetId:
            i < photoAssetIds.length && photoAssetIds[i].isNotEmpty
                ? photoAssetIds[i]
                : null,
        isPlaceholder: false,
      ),
  ];

  final galleryItems = isEditMode ? editGalleryItems : selectedItems;
  final selectedIds = galleryItems.map((e) => e.id).toList();

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => AddStoreProductBloc(
                storeId: storeId,
                initialState: AddStoreProductState(
                  storeId: storeId,
                  isEditMode: isEditMode,
                  listingId: listingId,
                  revision: revision,
                  title: title,
                  description: description,
                  tags: tags,
                  initialImagePaths: List<String>.from(imagePaths),
                  initialPhotoAssetIds: List<String>.from(photoAssetIds),
                  galleryItems: galleryItems,
                  selectedImageIds: selectedIds,
                ),
              ),
          child: const AddProductFormRoute(),
        ),
  );
}

PageRoute? _editProductSpecsRoute(RouteSettings settings) {
  final args = settings.arguments;
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : '';
  final listingId =
      args is Map && args['listingId'] is String
          ? args['listingId'] as String
          : '';
  final revision =
      args is Map && args['revision'] is int ? args['revision'] as int : 1;
  final title =
      args is Map && args['title'] is String ? args['title'] as String : '';
  final initialSpec =
      args is Map && args['specifications'] is ProductSpec
          ? args['specifications'] as ProductSpec
          : const ProductSpec();

  if (storeId.isEmpty || listingId.isEmpty) {
    debugPrint('edit_product_specs_route missing storeId/listingId');
    return null;
  }

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => EditProductSpecsRoute(
          storeId: storeId,
          listingId: listingId,
          revision: revision,
          initialSpec: initialSpec,
          productTitle: title,
        ),
  );
}

PageRoute? _collectionBrowseRoute(RouteSettings settings) {
  final args = settings.arguments;
  final product =
      args is Map && args['product'] is StoreProduct
          ? args['product'] as StoreProduct
          : StoreProduct.demoCatalog().first;
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : '';
  final storeName =
      args is Map && args['storeName'] is String
          ? args['storeName'] as String
          : 'Your Store';
  final storeLink =
      args is Map && args['storeLink'] is String
          ? args['storeLink'] as String
          : '';
  final isOwnStore =
      args is Map && args['isOwnStore'] is bool
          ? args['isOwnStore'] as bool
          : false;
  final seedProducts =
      args is Map && args['seedProducts'] is List<CatalogProduct>
          ? args['seedProducts'] as List<CatalogProduct>
          : null;

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => CollectionBrowseRoute(
          product: product,
          storeId: storeId,
          storeName: storeName,
          storeLink: storeLink,
          isOwnStore: isOwnStore,
          seedProducts: seedProducts,
        ),
  );
}

PageRoute? _productDetailsRoute(RouteSettings settings) {
  final args = settings.arguments;
  final product =
      args is Map && args['product'] is StoreProduct
          ? args['product'] as StoreProduct
          : args is StoreProduct
          ? args
          : StoreProduct.demoCatalog().first;
  final storeName =
      args is Map && args['storeName'] is String
          ? args['storeName'] as String
          : 'Your Store';
  final storeLink =
      args is Map && args['storeLink'] is String
          ? args['storeLink'] as String
          : 'your-store.jewelflow.app';
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : null;
  final imageIndex =
      args is Map && args['imageIndex'] is int ? args['imageIndex'] as int : 0;
  final isOwnStore =
      args is Map && args['isOwnStore'] is bool
          ? args['isOwnStore'] as bool
          : false;
  final galleryFeed =
      args is Map && args['galleryFeed'] is List<ProductDetailsFeedItem>
          ? args['galleryFeed'] as List<ProductDetailsFeedItem>
          : (args is Map && args['galleryFeed'] is List
              ? (args['galleryFeed'] as List)
                  .whereType<ProductDetailsFeedItem>()
                  .toList()
              : null);
  final galleryFeedIndex =
      args is Map && args['galleryFeedIndex'] is int
          ? args['galleryFeedIndex'] as int
          : 0;
  final seedCategory =
      args is Map && args['category'] is String
          ? (args['category'] as String).trim()
          : '';
  final showStoreGroupLink =
      args is Map && args['showStoreGroupLink'] == true;
  final likedPhotoIds = <String>{
    if (args is Map && args['likedPhotoIds'] is List)
      for (final e in args['likedPhotoIds'] as List)
        if (e is String && e.trim().isNotEmpty) e.trim(),
    if (args is Map &&
        args['likedPhotoId'] is String &&
        (args['likedPhotoId'] as String).trim().isNotEmpty)
      (args['likedPhotoId'] as String).trim(),
  };
  final initialIsWishlisted =
      args is Map && args['isWishlisted'] == true;
  final photoSourceRect =
      args is Map ? rectFromArgs(args['photoSourceRect']) : null;
  final photoPath =
      args is Map && args['photoPath'] is String
          ? (args['photoPath'] as String).trim()
          : '';
  final photoThumbhash =
      args is Map && args['photoThumbhash'] is String
          ? (args['photoThumbhash'] as String).trim()
          : null;
  final photoWidth =
      args is Map && args['photoWidth'] is num
          ? (args['photoWidth'] as num).toDouble()
          : null;
  final photoHeight =
      args is Map && args['photoHeight'] is num
          ? (args['photoHeight'] as num).toDouble()
          : null;
  final useTelegramPhoto =
      photoSourceRect != null && photoPath.isNotEmpty;

  Widget page(BuildContext context) => Theme(
    // Opaque black under the route transition (avoids white→black flicker
    // when opening immersive product details from a light screen).
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
    ),
    child: ColoredBox(
      color: Colors.black,
      child: BlocProvider(
        create:
            (_) => ProductDetailsBloc(
              product: product,
              storeName: storeName,
              storeLink: storeLink,
              storeId: storeId,
              isOwnStore: isOwnStore,
              initialImageIndex: imageIndex,
              galleryFeed: galleryFeed,
              galleryFeedIndex: galleryFeedIndex,
              seedCategory: seedCategory,
              showStoreGroupLink: showStoreGroupLink,
              initialLikedPhotoIds: likedPhotoIds,
              initialIsWishlisted: initialIsWishlisted,
            ),
        child: const ProductDetailsRoute(),
      ),
    ),
  );

  if (useTelegramPhoto) {
    return TelegramPhotoPageRoute(
      settings: settings,
      sourceRect: photoSourceRect,
      imagePath: photoPath,
      thumbhash:
          (photoThumbhash == null || photoThumbhash.isEmpty)
              ? null
              : photoThumbhash,
      imageWidth: photoWidth,
      imageHeight: photoHeight,
      builder: page,
    );
  }

  return _buildAnimatedRoute(settings: settings, builder: page);
}

PageRoute? _globalSearchRoute(RouteSettings settings) {
  final args = settings.arguments;
  final initialQuery =
      args is Map && args['initialQuery'] is String
          ? args['initialQuery'] as String
          : null;
  final initialCategory =
      args is Map && args['initialCategory'] is String
          ? args['initialCategory'] as String
          : null;
  return SmoothFadePageRoute<void>(
    settings: settings,
    builder:
        (context) => GlobalSearchRoute(
          initialQuery: initialQuery,
          initialCategory: initialCategory,
        ),
  );
}

PageRoute? _storeSearchRoute(RouteSettings settings) {
  final args = settings.arguments;
  final storeId =
      args is Map && args['storeId'] is String
          ? args['storeId'] as String
          : '';
  final storeName =
      args is Map && args['storeName'] is String
          ? args['storeName'] as String
          : 'Store';
  final storeCity =
      args is Map && args['storeCity'] is String
          ? args['storeCity'] as String
          : null;
  final productCount =
      args is Map && args['productCount'] is int
          ? args['productCount'] as int
          : null;
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => StoreSearchRoute(
          storeId: storeId,
          storeName: storeName,
          storeCity: storeCity,
          productCount: productCount,
        ),
  );
}

PageRoute? _searchFiltersRoute(RouteSettings settings) {
  final args = settings.arguments;
  if (args is! Map) return null;
  final scope =
      args['scope'] is SearchFilterScope
          ? args['scope'] as SearchFilterScope
          : SearchFilterScope.global;
  final initial =
      args['initial'] is SearchFilterSelection
          ? args['initial'] as SearchFilterSelection
          : const SearchFilterSelection();
  final initialCatalog =
      args['initialCatalog'] is SearchFilterCatalog
          ? args['initialCatalog'] as SearchFilterCatalog
          : const SearchFilterCatalog();
  final initialTotal =
      args['initialTotal'] is int ? args['initialTotal'] as int : 0;
  final loadPreview = args['loadPreview'];
  if (loadPreview is! SearchFilterPreviewLoader) return null;
  final storeName =
      args['storeName'] is String ? args['storeName'] as String : null;

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => SearchFiltersRoute(
          scope: scope,
          initial: initial,
          initialCatalog: initialCatalog,
          initialTotal: initialTotal,
          loadPreview: loadPreview,
          storeName: storeName,
        ),
  );
}

PageRoute? _homePlaceholderRoute(RouteSettings settings) {
  return _buildAnimatedRoute(
    settings: settings,
    builder: (context) => const HomePlaceholderRoute(),
  );
}

PageRoute _buildAnimatedRoute({
  required RouteSettings settings,
  required WidgetBuilder builder,
}) {
  return CupertinoPageRoute(settings: settings, builder: builder);
}
