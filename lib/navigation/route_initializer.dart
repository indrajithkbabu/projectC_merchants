import 'package:flutter/cupertino.dart';
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
import 'package:project_c/models/store_channel.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/add_store_product/add_product_form_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_gallery_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_group_details_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_group_preview_route.dart';
import 'package:project_c/presentation/add_store_product/add_product_group_route.dart';
import 'package:project_c/presentation/add_store_product/edit_product_specs_route.dart';
import 'package:project_c/presentation/auth/country_picker_route.dart';
import 'package:project_c/presentation/auth/otp_route.dart';
import 'package:project_c/presentation/auth/phone_route.dart';
import 'package:project_c/presentation/home/home_placeholder_route.dart';
import 'package:project_c/presentation/bootstrap/bootstrap_route.dart';
import 'package:project_c/presentation/main_shell/main_shell_route.dart';
import 'package:project_c/presentation/onboarding/onboarding_route.dart';
import 'package:project_c/presentation/product_details/product_details_route.dart';
import 'package:project_c/presentation/profile/profile_route.dart';
import 'package:project_c/presentation/store_gallery/store_gallery_route.dart';
import 'package:project_c/presentation/store_import/store_import_approved_route.dart';
import 'package:project_c/presentation/store_import/store_import_pending_route.dart';
import 'package:project_c/presentation/store_import/store_import_requests_route.dart';
import 'package:project_c/presentation/store_import/store_import_select_route.dart';
import 'package:project_c/presentation/store_setup/store_setup_route.dart';
import 'package:project_c/presentation/storeprofile/collection_browse_route.dart';
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
    case Routes.countryPickerRoute:
      return _countryPickerRoute(settings);
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
                avatarColor: avatarColor,
              ),
          child: const StoreProfileRoute(),
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
          child: const StoreGalleryRoute(),
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
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => ImportRequestsBloc(
                storeId: storeId,
                storeName: storeName,
              ),
          child: const StoreImportRequestsRoute(),
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
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
          create:
              (_) => BulkUploadBloc(images: selectedItems, storeId: storeId),
          child: const AddProductGroupRoute(),
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
  final autoOpenEdit =
      settings.arguments is Map &&
      (settings.arguments as Map)['autoOpenEdit'] == true;
  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider.value(
          value: bloc,
          child: AddProductGroupPreviewRoute(autoOpenEdit: autoOpenEdit),
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

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => CollectionBrowseRoute(
          product: product,
          storeId: storeId,
          storeName: storeName,
          storeLink: storeLink,
          isOwnStore: isOwnStore,
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

  return _buildAnimatedRoute(
    settings: settings,
    builder:
        (context) => BlocProvider(
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
              ),
          child: const ProductDetailsRoute(),
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
