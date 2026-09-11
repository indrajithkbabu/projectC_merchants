import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/webservice/catalog_api_exception.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

part 'product_details_event.dart';
part 'product_details_state.dart';

class ProductDetailsBloc
    extends Bloc<ProductDetailsEvent, ProductDetailsState> {
  ProductDetailsBloc({
    required StoreProduct product,
    required String storeName,
    required String storeLink,
    String? storeId,
    bool isOwnStore = false,
    int initialImageIndex = 0,
    CollectionRepository? collectionRepository,
  }) : _collectionRepository =
           collectionRepository ??
           ServiceLocator.get<CollectionRepository>(),
       super(
         ProductDetailsState(
           product: product,
           storeName: storeName,
           storeLink: storeLink,
           storeId: storeId,
           isOwnStore: isOwnStore,
           initialImageIndex: _clampIndex(initialImageIndex, product),
           isLoadingPhotos: _canFetchPhotos(storeId, product),
           canEdit: _resolveCanEdit(
             explicit: product.canEdit,
             isOwnStore: isOwnStore,
             kind: _kindFromProduct(product),
           ),
           canDelete: product.canDelete || isOwnStore,
         ),
       ) {
    on<ProductDetailsLoadPhotos>(_onLoadPhotos);
    on<ProductDetailsSharePressed>(_onSharePressed);
    on<ProductDetailsEditPressed>(_onEditPressed);
    on<ProductDetailsDeletePressed>(_onDeletePressed);
    on<ProductDetailsClearOpenEdit>(_onClearOpenEdit);
    on<ProductDetailsApplyEditedProduct>(_onApplyEditedProduct);
    on<ProductDetailsClearDeleted>(_onClearDeleted);
    on<ProductDetailsMorePressed>(_onMorePressed);
    on<ProductDetailsClearMessage>(_onClearMessage);
    if (_canFetchPhotos(storeId, product)) {
      add(const ProductDetailsLoadPhotos());
    }
  }

  final CollectionRepository _collectionRepository;
  static const _tag = 'ProductDetailsBloc';

  static bool _canFetchPhotos(String? storeId, StoreProduct product) {
    if (storeId == null || storeId.isEmpty) return false;
    if (storeId == 'my_store' || storeId == 'other_store') return false;
    if (product.id.trim().isEmpty) return false;
    return true;
  }

  static String? _kindFromProduct(StoreProduct product) {
    if (product.tags.contains('imported')) return 'imported';
    if (product.tags.contains('original')) return 'original';
    return null;
  }

  static bool _resolveCanEdit({
    bool? explicit,
    required bool isOwnStore,
    String? kind,
  }) {
    if (explicit == true) return true;
    if (!isOwnStore) return false;
    return kind != 'imported';
  }

  static int _clampIndex(int index, StoreProduct product) {
    final last = product.imagePaths.isEmpty ? 0 : product.imagePaths.length - 1;
    if (index < 0) return 0;
    if (index > last) return last;
    return index;
  }

  Future<void> _onLoadPhotos(
    ProductDetailsLoadPhotos event,
    Emitter<ProductDetailsState> emit,
  ) async {
    final storeId = state.storeId;
    if (!_canFetchPhotos(storeId, state.product)) {
      emit(state.copyWith(isLoadingPhotos: false));
      return;
    }

    emit(state.copyWith(isLoadingPhotos: true));
    try {
      final detail = await _collectionRepository.fetchCollection(
        storeId: storeId!,
        listingId: state.product.id,
      );
      final updated = CatalogUiMapper.detailToProduct(detail);
      final perms = detail.permissions;
      AppLog.d(
        _tag,
        'Loaded collection detail photos=${updated.imagePaths.length} '
        'edit=${perms?.edit} delete=${perms?.delete}',
      );
      emit(
        state.copyWith(
          product: updated,
          isLoadingPhotos: false,
          initialImageIndex: _clampIndex(state.initialImageIndex, updated),
          revision: detail.revision,
          apiTag: detail.tag,
          canEdit: _resolveCanEdit(
            explicit: perms?.edit ?? updated.canEdit,
            isOwnStore: state.isOwnStore,
            kind: detail.kind ?? _kindFromProduct(updated),
          ),
          canDelete: (perms?.delete ?? updated.canDelete) || state.isOwnStore,
        ),
      );
    } catch (e) {
      // Keep cover/local images already on the product; do not block the screen.
      AppLog.e(_tag, 'Collection detail load failed', e);
      emit(
        state.copyWith(
          isLoadingPhotos: false,
          canEdit: _resolveCanEdit(
            explicit: state.canEdit,
            isOwnStore: state.isOwnStore,
            kind: _kindFromProduct(state.product),
          ),
          canDelete: state.canDelete || state.isOwnStore,
        ),
      );
    }
  }

  void _onSharePressed(
    ProductDetailsSharePressed event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'Product link ready to share.'));
  }

  void _onEditPressed(
    ProductDetailsEditPressed event,
    Emitter<ProductDetailsState> emit,
  ) {
    if (!state.canEdit) {
      emit(
        state.copyWith(
          infoMessage: 'You do not have permission to edit this product.',
        ),
      );
      return;
    }
    final storeId = state.storeId;
    if (storeId == null ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      emit(state.copyWith(infoMessage: 'Unable to edit this product right now.'));
      return;
    }
    emit(state.copyWith(shouldOpenEdit: true));
  }

  Future<void> _onDeletePressed(
    ProductDetailsDeletePressed event,
    Emitter<ProductDetailsState> emit,
  ) async {
    if (state.isDeleting) return;
    if (!state.canEdit) {
      emit(
        state.copyWith(
          infoMessage: 'You do not have permission to remove this photo.',
        ),
      );
      return;
    }
    final storeId = state.storeId;
    if (storeId == null ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      emit(
        state.copyWith(infoMessage: 'Unable to remove this photo right now.'),
      );
      return;
    }

    final paths = state.product.imagePaths;
    if (paths.length <= 1) {
      await _deleteProduct(emit);
      return;
    }

    final index = event.imageIndex;
    if (index < 0 || index >= paths.length) {
      emit(state.copyWith(infoMessage: 'This photo is no longer available.'));
      return;
    }

    var photoId =
        index < state.product.photoAssetIds.length
            ? state.product.photoAssetIds[index].trim()
            : '';
    var revision = state.revision;

    if (photoId.isEmpty) {
      try {
        final detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: state.product.id,
        );
        revision = detail.revision;
        if (index < detail.photos.length) {
          photoId = detail.photos[index].id?.trim() ?? '';
        }
      } catch (e) {
        AppLog.e(_tag, 'Unable to resolve photo id', e);
      }
    }

    if (photoId.isEmpty) {
      emit(
        state.copyWith(
          infoMessage: 'Unable to remove this photo right now.',
        ),
      );
      return;
    }

    emit(state.copyWith(isDeleting: true));
    try {
      final deleted = await _collectionRepository.deletePhotos(
        storeId: storeId,
        listingId: state.product.id,
        photoIds: [photoId],
        revision: revision,
      );
      CollectionDetail detail;
      try {
        detail = await _collectionRepository.fetchCollection(
          storeId: storeId,
          listingId: state.product.id,
        );
      } catch (_) {
        final nextPaths = List<String>.from(paths)..removeAt(index);
        final nextIds = List<String>.from(state.product.photoAssetIds);
        if (index < nextIds.length) nextIds.removeAt(index);
        emit(
          state.copyWith(
            isDeleting: false,
            product: state.product.copyWith(
              imagePaths: nextPaths,
              photoAssetIds: nextIds,
            ),
            revision: deleted.revision,
            initialImageIndex: _clampIndex(
              index > 0 ? index - 1 : 0,
              state.product.copyWith(imagePaths: nextPaths),
            ),
            infoMessage: 'Photo removed.',
          ),
        );
        return;
      }

      final updated = CatalogUiMapper.detailToProduct(detail);
      AppLog.d(_tag, 'Removed photo $photoId from ${state.product.id}');
      emit(
        state.copyWith(
          isDeleting: false,
          product: updated,
          revision: detail.revision,
          apiTag: detail.tag,
          canEdit: detail.permissions?.edit ?? state.canEdit,
          canDelete: detail.permissions?.delete ?? state.canDelete,
          initialImageIndex: _clampIndex(index > 0 ? index - 1 : 0, updated),
          infoMessage: 'Photo removed.',
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Delete photo failed', e);
      emit(
        state.copyWith(
          isDeleting: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Emitter<ProductDetailsState> emit) async {
    final storeId = state.storeId;
    if (storeId == null ||
        storeId.isEmpty ||
        storeId == 'my_store' ||
        storeId == 'other_store') {
      emit(
        state.copyWith(infoMessage: 'Unable to delete this product right now.'),
      );
      return;
    }

    emit(state.copyWith(isDeleting: true));
    try {
      await _collectionRepository.deleteCollection(
        storeId: storeId,
        listingId: state.product.id,
      );
      AppLog.d(_tag, 'Deleted collection ${state.product.id}');
      emit(state.copyWith(isDeleting: false, isDeleted: true));
    } catch (e) {
      AppLog.e(_tag, 'Delete collection failed', e);
      final alreadyGone =
          e is CatalogApiException &&
          (e.statusCode == 404 || e.code == 'COLLECTION_NOT_FOUND');
      if (alreadyGone) {
        emit(state.copyWith(isDeleting: false, isDeleted: true));
        return;
      }
      emit(
        state.copyWith(
          isDeleting: false,
          infoMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  void _onClearOpenEdit(
    ProductDetailsClearOpenEdit event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearShouldOpenEdit: true));
  }

  void _onApplyEditedProduct(
    ProductDetailsApplyEditedProduct event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(
      state.copyWith(
        product: event.product.copyWith(
          canEdit: event.product.canEdit || state.canEdit,
          canDelete: event.product.canDelete || state.canDelete,
        ),
        canEdit: event.product.canEdit || state.canEdit,
        canDelete: event.product.canDelete || state.canDelete,
        revision: event.revision,
        apiTag: event.apiTag,
        initialImageIndex: _clampIndex(state.initialImageIndex, event.product),
        infoMessage: 'Product updated.',
      ),
    );
  }

  void _onClearDeleted(
    ProductDetailsClearDeleted event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearDeleted: true));
  }

  void _onMorePressed(
    ProductDetailsMorePressed event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(infoMessage: 'More actions coming soon.'));
  }

  void _onClearMessage(
    ProductDetailsClearMessage event,
    Emitter<ProductDetailsState> emit,
  ) {
    emit(state.copyWith(clearInfoMessage: true));
  }
}
