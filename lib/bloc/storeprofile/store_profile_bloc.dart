import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/session/catalog_session.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';
import 'package:project_c/webservice/import/import_repository.dart';
import 'package:project_c/webservice/store/store_repository.dart';

part 'store_profile_event.dart';
part 'store_profile_state.dart';

class StoreProfileBloc extends Bloc<StoreProfileEvent, StoreProfileState> {
  StoreProfileBloc({
    required String storeName,
    required List<TeamMember> members,
    List<StoreProduct>? products,
    bool isOwnStore = true,
    String? storeId,
    String? storeLink,
    int avatarColor = 0xFF2AABEE,
    CollectionRepository? collectionRepository,
    StoreRepository? storeRepository,
    ImportRepository? importRepository,
    CatalogSession? session,
  }) : _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       _storeRepository =
           storeRepository ?? ServiceLocator.get<StoreRepository>(),
       _importRepository =
           importRepository ?? ServiceLocator.get<ImportRepository>(),
       _session = session ?? ServiceLocator.get<CatalogSession>(),
       super(
         StoreProfileState(
           storeName:
               storeName.trim().isEmpty ? 'Your Store' : storeName.trim(),
           members: members,
           products: products ?? const [],
           isOwnStore: isOwnStore,
           storeId: storeId ?? (isOwnStore ? 'my_store' : 'other_store'),
           avatarColor: avatarColor,
           overrideStoreLink: storeLink,
           currentUserId: (session ?? ServiceLocator.get<CatalogSession>())
               .profile
               ?.id,
           isLoadingProducts: true,
           isLoadingMembers: isOwnStore,
         ),
       ) {
    on<StoreProfileAddProductsPressed>(_onAddProductsPressed);
    on<StoreProfileProductPublished>(_onProductPublished);
    on<StoreProfileProductUpdated>(_onProductUpdated);
    on<StoreProfileProductDeleted>(_onProductDeleted);
    on<StoreProfileProductsReplaced>(_onProductsReplaced);
    on<StoreProfileProductsImported>(_onProductsImported);
    on<StoreProfileImportPressed>(_onImportPressed);
    on<StoreProfileSharePressed>(_onSharePressed);
    on<StoreProfileMorePressed>(_onMorePressed);
    on<StoreProfileQuickAddPressed>(_onQuickAddPressed);
    on<StoreProfileClearMessage>(_onClearMessage);
    on<StoreProfileLoadCollections>(_onLoadCollections);
    on<StoreProfileLoadMembers>(_onLoadMembers);
    on<StoreProfileLoadImportRequestCount>(_onLoadImportRequestCount);
    add(const StoreProfileLoadCollections());
    if (isOwnStore) {
      add(const StoreProfileLoadMembers());
      add(const StoreProfileLoadImportRequestCount());
    }
  }

  final CollectionRepository _collectionRepository;
  final StoreRepository _storeRepository;
  final ImportRepository _importRepository;
  final CatalogSession _session;
  static const _tag = 'StoreProfileBloc';

  static const _avatarPalette = <int>[
    0xFF2AABEE,
    0xFFE74C3C,
    0xFF3498DB,
    0xFF2ECC71,
    0xFFE67E22,
    0xFF9B59B6,
    0xFF1ABC9C,
    0xFFE91E63,
  ];

  Future<void> _onLoadCollections(
    StoreProfileLoadCollections event,
    Emitter<StoreProfileState> emit,
  ) async {
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(state.copyWith(isLoadingProducts: false));
      return;
    }
    emit(state.copyWith(isLoadingProducts: true, clearError: true));
    try {
      final page = await _collectionRepository.listCollections(
        storeId: storeId,
        limit: 50,
      );
      // Covers first so the grid appears quickly.
      final covers =
          page.items.map(CatalogUiMapper.summaryToProduct).toList();
      AppLog.d(_tag, 'Loaded ${covers.length} collections');
      emit(
        state.copyWith(
          products: covers,
          isLoadingProducts: false,
        ),
      );

      // List API only returns cover; fetch details for full photo URLs.
      final enriched = await Future.wait([
        for (final summary in page.items)
          _productFromSummary(storeId: storeId, summary: summary),
      ]);
      if (emit.isDone) return;
      AppLog.d(_tag, 'Enriched ${enriched.length} collections with photos');
      emit(state.copyWith(products: enriched));
    } catch (e) {
      AppLog.e(_tag, 'Collections load failed', e);
      emit(
        state.copyWith(
          isLoadingProducts: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<StoreProduct> _productFromSummary({
    required String storeId,
    required CollectionSummary summary,
  }) async {
    if (summary.photoCount <= 1) {
      return CatalogUiMapper.summaryToProduct(summary);
    }
    try {
      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId,
        listingId: summary.id,
      );
      return CatalogUiMapper.detailToProduct(detail);
    } catch (e) {
      AppLog.e(_tag, 'Collection detail enrich failed id=${summary.id}', e);
      return CatalogUiMapper.summaryToProduct(summary);
    }
  }

  Future<void> _onLoadMembers(
    StoreProfileLoadMembers event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore) {
      emit(state.copyWith(isLoadingMembers: false));
      return;
    }
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(state.copyWith(isLoadingMembers: false));
      return;
    }

    emit(
      state.copyWith(
        isLoadingMembers: true,
        currentUserId: _session.profile?.id ?? state.currentUserId,
        clearError: true,
      ),
    );
    try {
      final all = <StoreMember>[];
      String? cursor;
      do {
        final page = await _storeRepository.fetchMembers(
          storeId: storeId,
          limit: 50,
          cursor: cursor,
        );
        all.addAll(page.items);
        cursor = page.nextCursor;
      } while (cursor != null && cursor.isNotEmpty);

      final mapped = [
        for (var i = 0; i < all.length; i++) _mapMember(all[i], i),
      ];
      AppLog.d(_tag, 'Loaded ${mapped.length} store members');
      emit(
        state.copyWith(
          members: mapped,
          isLoadingMembers: false,
          currentUserId: _session.profile?.id ?? state.currentUserId,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Members load failed', e);
      emit(
        state.copyWith(
          isLoadingMembers: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onLoadImportRequestCount(
    StoreProfileLoadImportRequestCount event,
    Emitter<StoreProfileState> emit,
  ) async {
    if (!state.isOwnStore) return;
    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      return;
    }
    try {
      var pending = 0;
      String? cursor;
      do {
        final page = await _importRepository.listStoreRequests(
          storeId: storeId,
          direction: 'incoming',
          limit: 50,
          cursor: cursor,
        );
        pending += page.items.where((r) => r.isPending).length;
        cursor = page.nextCursor;
      } while (cursor != null && cursor.isNotEmpty);
      if (emit.isDone) return;
      AppLog.d(_tag, 'Pending incoming import requests=$pending');
      emit(state.copyWith(pendingImportRequestCount: pending));
    } catch (e) {
      // Badge is secondary; do not interrupt the profile with a snackbar.
      AppLog.e(_tag, 'Import request count failed', e);
    }
  }

  TeamMember _mapMember(StoreMember member, int index) {
    return TeamMember(
      id: member.userId,
      name: member.displayName,
      handle: member.phone,
      phone: member.phone,
      avatarColor: _avatarPalette[index % _avatarPalette.length],
    );
  }

  void _onAddProductsPressed(
    StoreProfileAddProductsPressed event,
    Emitter<StoreProfileState> emit,
  ) {}

  void _onProductPublished(
    StoreProfileProductPublished event,
    Emitter<StoreProfileState> emit,
  ) {
    final next = [
      event.product.copyWith(
        canEdit: event.product.canEdit || state.isOwnStore,
        canDelete: event.product.canDelete || state.isOwnStore,
      ),
      ...state.products,
    ];
    emit(
      state.copyWith(
        products: next,
        infoMessage: 'Product published to store.',
      ),
    );
  }

  void _onProductUpdated(
    StoreProfileProductUpdated event,
    Emitter<StoreProfileState> emit,
  ) {
    final replacedId = event.replacedListingId?.trim();
    final next = <StoreProduct>[];
    var replaced = false;
    for (final product in state.products) {
      if (product.id == event.product.id ||
          (replacedId != null &&
              replacedId.isNotEmpty &&
              product.id == replacedId)) {
        if (!replaced) {
          next.add(
            event.product.copyWith(
              canEdit: event.product.canEdit || state.isOwnStore,
              canDelete: event.product.canDelete || state.isOwnStore,
            ),
          );
          replaced = true;
        }
        continue;
      }
      next.add(product);
    }
    if (!replaced) {
      next.insert(0, event.product);
    }
    emit(
      state.copyWith(
        products: next,
        infoMessage: 'Product updated.',
      ),
    );
  }

  Future<void> _onProductDeleted(
    StoreProfileProductDeleted event,
    Emitter<StoreProfileState> emit,
  ) async {
    final productId = event.productId.trim();
    if (productId.isEmpty || state.deletingProductId != null) return;

    final storeId = state.storeId;
    if (storeId.isEmpty || storeId == 'my_store' || storeId == 'other_store') {
      emit(
        state.copyWith(
          products: state.products.where((p) => p.id != productId).toList(),
          infoMessage: 'Product deleted.',
        ),
      );
      return;
    }

    emit(state.copyWith(deletingProductId: productId, clearError: true));
    try {
      await _collectionRepository.deleteCollection(
        storeId: storeId,
        listingId: productId,
      );
      AppLog.d(_tag, 'Deleted collection $productId');
      emit(
        state.copyWith(
          products: state.products.where((p) => p.id != productId).toList(),
          clearDeletingProductId: true,
          infoMessage: 'Product deleted.',
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Delete collection failed', e);
      final alreadyGone =
          e is CatalogApiException &&
          (e.statusCode == 404 || e.code == 'COLLECTION_NOT_FOUND');
      if (alreadyGone) {
        emit(
          state.copyWith(
            products: state.products.where((p) => p.id != productId).toList(),
            clearDeletingProductId: true,
            infoMessage: 'Product deleted.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          clearDeletingProductId: true,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onProductsReplaced(
    StoreProfileProductsReplaced event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(products: event.products));
  }

  void _onProductsImported(
    StoreProfileProductsImported event,
    Emitter<StoreProfileState> emit,
  ) {
    final next = [...event.products, ...state.products];
    emit(
      state.copyWith(
        products: next,
        infoMessage: 'Imported products are live in your store.',
      ),
    );
  }

  void _onImportPressed(
    StoreProfileImportPressed event,
    Emitter<StoreProfileState> emit,
  ) {}

  void _onSharePressed(
    StoreProfileSharePressed event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'Store link ready to share.'));
  }

  void _onMorePressed(
    StoreProfileMorePressed event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'More actions coming soon.'));
  }

  void _onQuickAddPressed(
    StoreProfileQuickAddPressed event,
    Emitter<StoreProfileState> emit,
  ) {}

  void _onClearMessage(
    StoreProfileClearMessage event,
    Emitter<StoreProfileState> emit,
  ) {
    emit(state.copyWith(clearInfoMessage: true, clearError: true));
  }
}
