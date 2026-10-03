import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:project_c/bloc/bulk_upload/bulk_upload_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_subgroup_name.dart';
import 'package:project_c/helper/catalog_ui_mapper.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/bulk_upload.dart';
import 'package:project_c/models/catalog/collection_models.dart';
import 'package:project_c/models/catalog/collection_specifications.dart';
import 'package:project_c/models/product_details_feed_item.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/collection/collection_repository.dart';

/// Collection photo browse — gallery-style date / section titles / pinch zoom,
/// with own-store Select → Edit / Ungroup. Keeps the standard app background.
class CollectionBrowseRoute extends StatefulWidget {
  const CollectionBrowseRoute({
    super.key,
    required this.product,
    required this.storeId,
    required this.storeName,
    required this.storeLink,
    this.isOwnStore = false,
    this.pageTitle,
    this.forcedSingles,
    this.seedDetail,
  });

  final StoreProduct product;
  final String storeId;
  final String storeName;
  final String storeLink;
  final bool isOwnStore;

  /// Optional title override (legacy nested browse).
  final String? pageTitle;

  /// When set, skip fetch and show these photos only.
  final List<CatalogPhoto>? forcedSingles;

  /// Shared detail for imageIndex resolution when [forcedSingles] is set.
  final CollectionDetail? seedDetail;

  @override
  State<CollectionBrowseRoute> createState() => _CollectionBrowseRouteState();
}

class _CollectionBrowseRouteState extends State<CollectionBrowseRoute> {
  static const _logTag = 'BulkQA.Browse';
  static const _minColumns = 4;

  CollectionDetail? _detail;
  StoreProduct? _product;
  bool _loading = true;
  bool _busy = false;
  bool _selectMode = false;
  final Set<String> _selectedPhotoIds = {};
  String? _error;
  Object? _popResult;
  int _crossAxisCount = 5;
  double _pinchStartColumns = 5;

  bool get _canManage =>
      widget.isOwnStore && widget.forcedSingles == null && _detail != null;

  @override
  void initState() {
    super.initState();
    if (widget.forcedSingles != null && widget.seedDetail != null) {
      _detail = widget.seedDetail;
      _product = CatalogUiMapper.detailToProduct(widget.seedDetail!);
      _loading = false;
      _logTiles(_tiles());
    } else {
      _load();
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repository = ServiceLocator.get<CollectionRepository>();
      final detail = await repository.fetchCollection(
        storeId: widget.storeId,
        listingId: widget.product.id,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _product = CatalogUiMapper.detailToProduct(detail);
        _loading = false;
        _busy = false;
        _selectedPhotoIds.clear();
        // Keep select mode if user was managing; drop empty selection.
      });
      AppLog.d(
        _logTag,
        'loaded listing=${detail.id} photos=${detail.photoCount} '
        'main=${detail.mainGroupPhotos.length} subs=${detail.subGroups.length}',
      );
      _logTiles(_tiles());
    } catch (e) {
      if (!mounted) return;
      AppLog.e(_logTag, 'load failed', e);
      setState(() {
        _loading = false;
        _busy = false;
        _error = CatalogErrorMapper.toUserMessage(e);
      });
    }
  }

  Set<String> _precisePhotoKeys(CollectionDetail detail) {
    final keys = <String>{};
    for (final sub in detail.subGroups) {
      final isStandalone = sub.name.toLowerCase().contains('standalone');
      if (isStandalone) continue;
      for (final photo in sub.photos) {
        final id = photo.id?.trim() ?? '';
        if (id.isNotEmpty) {
          keys.add('id:$id');
          continue;
        }
        final url = photo.url.trim();
        if (url.isNotEmpty) keys.add('url:$url');
      }
    }
    return keys;
  }

  bool _isPrecise(CatalogPhoto photo, Set<String> preciseKeys) {
    final id = photo.id?.trim() ?? '';
    if (id.isNotEmpty && preciseKeys.contains('id:$id')) return true;
    final url = photo.url.trim();
    return url.isNotEmpty && preciseKeys.contains('url:$url');
  }

  String _collectionDisplayName() {
    final fromPage = widget.pageTitle?.trim() ?? '';
    if (fromPage.isNotEmpty) return fromPage;
    final fromDetail = _detail?.name.trim() ?? '';
    if (fromDetail.isNotEmpty) return fromDetail;
    final fromProduct = widget.product.title.trim();
    if (fromProduct.isNotEmpty) return fromProduct;
    return 'Item';
  }

  List<_BrowseTile> _tiles() {
    final forced = widget.forcedSingles;
    final detail = _detail;
    final preciseKeys =
        detail == null ? const <String>{} : _precisePhotoKeys(detail);
    final collectionName = _collectionDisplayName();

    // Legacy nested browse: flat forced list under the page title.
    if (forced != null) {
      final photos = [
        for (final p in forced)
          if (p.url.trim().isNotEmpty) p,
      ];
      return [
        for (var i = 0; i < photos.length; i++)
          _BrowseTile(
            photo: photos[i],
            sectionKey: 'forced',
            sectionTitle: collectionName,
            label: '$collectionName ${i + 1}',
            isPrecise: false,
          ),
      ];
    }

    if (detail == null) return const [];

    // Main first, then each sub-group. Auto-named Precise/Standalone clusters
    // share the collection section; custom sub-group names keep their own.
    final tiles = <_BrowseTile>[];
    final mainPhotos = [
      for (final p in detail.mainGroupPhotos)
        if (p.url.trim().isNotEmpty) p,
    ];
    for (var i = 0; i < mainPhotos.length; i++) {
      tiles.add(
        _BrowseTile(
          photo: mainPhotos[i],
          sectionKey: 'main',
          sectionTitle: collectionName,
          label: '$collectionName ${i + 1}',
          isPrecise: false,
        ),
      );
    }

    for (final sub in detail.subGroups) {
      final subId = sub.id.trim();
      final rawName = sub.name.trim();
      final subName = rawName.isNotEmpty ? rawName : collectionName;
      final subPhotos = [
        for (final p in sub.photos)
          if (p.url.trim().isNotEmpty) p,
      ];
      final isStandalone = rawName.toLowerCase().contains('standalone');
      // Auto `{title} precise|standalone {n}` merges under the collection
      // title; blue dot still marks Precise. Custom names keep a section.
      final autoNamed = isAutoGeneratedSubGroupName(rawName);
      final sectionKey =
          autoNamed
              ? 'main'
              : (subId.isNotEmpty ? 'sub:$subId' : 'sub:$subName');
      final sectionTitle = autoNamed ? collectionName : subName;
      for (var i = 0; i < subPhotos.length; i++) {
        final photo = subPhotos[i];
        tiles.add(
          _BrowseTile(
            photo: photo,
            sectionKey: sectionKey,
            sectionTitle: sectionTitle,
            label: '$subName ${i + 1}',
            isPrecise: !isStandalone && _isPrecise(photo, preciseKeys),
            subGroupId: subId.isEmpty ? null : subId,
          ),
        );
      }
    }

    // Orphan photos present only on the flat list (should be rare).
    final seen = <String>{
      for (final t in tiles)
        if ((t.photo.id?.trim() ?? '').isNotEmpty) t.photo.id!.trim(),
    };
    var orphanIndex = 0;
    for (final photo in detail.photos) {
      if (photo.url.trim().isEmpty) continue;
      final id = photo.id?.trim() ?? '';
      if (id.isNotEmpty && seen.contains(id)) continue;
      if (id.isEmpty) {
        final already =
            tiles.any((t) => t.photo.url.trim() == photo.url.trim());
        if (already) continue;
      }
      orphanIndex += 1;
      tiles.add(
        _BrowseTile(
          photo: photo,
          sectionKey: 'main',
          sectionTitle: collectionName,
          label: '$collectionName ${mainPhotos.length + orphanIndex}',
          isPrecise: _isPrecise(photo, preciseKeys),
        ),
      );
    }

    return tiles;
  }

  List<_BrowseSection> _sections(List<_BrowseTile> tiles) {
    final order = <String>[];
    final byKey = <String, List<_BrowseTile>>{};
    final titles = <String, String>{};
    for (final tile in tiles) {
      if (!byKey.containsKey(tile.sectionKey)) {
        order.add(tile.sectionKey);
        titles[tile.sectionKey] = tile.sectionTitle;
      }
      byKey.putIfAbsent(tile.sectionKey, () => []).add(tile);
    }
    return [
      for (final key in order)
        _BrowseSection(
          key: key,
          title: titles[key] ?? _collectionDisplayName(),
          tiles: byKey[key]!,
        ),
    ];
  }

  void _onScaleStart(ScaleStartDetails details) {
    _pinchStartColumns = _crossAxisCount.toDouble();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;
    final width = MediaQuery.sizeOf(context).width;
    final maxColumns = (width / 20).floor();
    final upper =
        maxColumns < _minColumns ? _minColumns : maxColumns;
    final next = (_pinchStartColumns / details.scale).round().clamp(
      _minColumns,
      upper,
    );
    if (next != _crossAxisCount) {
      setState(() => _crossAxisCount = next);
    }
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _dateLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}';
  }

  void _logTiles(List<_BrowseTile> tiles) {
    final precise = tiles.where((t) => t.isPrecise).length;
    AppLog.d(
      _logTag,
      'tiles total=${tiles.length} precise=$precise '
      'listing=${widget.product.id} title="${widget.product.title}"',
    );
    for (var i = 0; i < tiles.length; i++) {
      final t = tiles[i];
      AppLog.d(
        _logTag,
        '  [$i] label="${t.label}" id=${t.photo.id ?? '-'} '
        'precise=${t.isPrecise} sub=${t.subGroupId ?? '-'}',
      );
    }
  }

  int _imageIndexFor(CatalogPhoto photo) {
    final detail = _detail;
    if (detail == null) return 0;
    final photoId = photo.id?.trim() ?? '';
    if (photoId.isNotEmpty) {
      final byId = detail.photos.indexWhere(
        (p) => (p.id?.trim() ?? '') == photoId,
      );
      if (byId >= 0) return byId;
    }
    final url = photo.url.trim();
    final byUrl = detail.photos.indexWhere((p) => p.url.trim() == url);
    return byUrl >= 0 ? byUrl : 0;
  }

  Future<void> _openPhoto(CatalogPhoto photo) async {
    final product = _product ?? widget.product;
    final tiles = _tiles();
    final feed = <ProductDetailsFeedItem>[
      for (final tile in tiles)
        ProductDetailsFeedItem(
          product: product,
          imageIndex: _imageIndexFor(tile.photo),
          path: tile.photo.url,
        ),
    ];
    final tappedIndex = _imageIndexFor(photo);
    var feedIndex = feed.indexWhere((e) => e.imageIndex == tappedIndex);
    if (feedIndex < 0) {
      feedIndex = feed.indexWhere(
        (e) => e.path.trim() == photo.url.trim(),
      );
    }
    if (feedIndex < 0) feedIndex = 0;

    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': product,
        'storeId': widget.storeId,
        'storeName': widget.storeName,
        'storeLink': widget.storeLink,
        'isOwnStore': widget.isOwnStore,
        'imageIndex': tappedIndex,
        'galleryFeed': feed,
        'galleryFeedIndex': feedIndex,
      },
    );
    if (!mounted) return;
    if (result is Map) {
      final payload = Map<String, Object?>.from(result);
      _popResult = payload;
      if (payload['deleted'] == true) {
        Navigator.of(context).pop(payload);
        return;
      }
      if (payload['updated'] == true) {
        if (widget.forcedSingles == null) {
          await _load();
        } else if (payload.containsKey('id')) {
          setState(() {
            _product = StoreProduct.fromMap(payload);
          });
        }
      }
    }
  }

  void _toggleSelect(String photoId) {
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  void _setSelectMode(bool enabled) {
    setState(() {
      _selectMode = enabled;
      if (!enabled) _selectedPhotoIds.clear();
    });
  }

  Future<void> _openEditSelected() async {
    if (_busy || _selectedPhotoIds.isEmpty) return;
    final selectedIds = _selectedPhotoIds.toList(growable: false);
    AppLog.d(
      _logTag,
      'Edit selected count=${selectedIds.length} ids=${selectedIds.join(',')}',
    );

    setState(() => _busy = true);
    BulkUploadBloc? bloc;
    try {
      final detail = await ServiceLocator.get<CollectionRepository>()
          .fetchCollection(
            storeId: widget.storeId,
            listingId: widget.product.id,
          );
      if (!mounted) return;

      bloc = BulkUploadBloc.fromCollectionDetail(
        detail: detail,
        storeId: widget.storeId,
      );
      final known = bloc.state.items.map((item) => item.id).toSet();
      final validIds = [
        for (final id in selectedIds)
          if (known.contains(id)) id,
      ];
      if (validIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not match the selected photos for editing.'),
          ),
        );
        return;
      }

      bloc.add(BulkUploadSelectionSet(validIds));

      final result = await Navigator.of(context).pushNamed(
        Routes.addProductGroupPreviewRoute,
        arguments: <String, Object?>{
          'bloc': bloc,
          'autoOpenEdit': true,
        },
      );
      if (!mounted) return;

      if (result is Map) {
        final payload = Map<String, Object?>.from(result);
        if (payload['updated'] == true) {
          _popResult = <String, Object?>{
            ...payload,
            'refreshCollections': true,
          };
          _setSelectMode(false);
          await _load(quiet: true);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Changes saved.')),
          );
          return;
        }
      }

      _setSelectMode(false);
      await _load(quiet: true);
    } catch (e) {
      AppLog.e(_logTag, 'FAIL open edit selected', e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    } finally {
      await bloc?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  List<CollectionSubGroup> _existingTargets(String sourceSubGroupId) {
    final detail = _detail;
    if (detail == null) return const [];
    return [
      for (final sub in detail.subGroups)
        if (sub.id.trim().isNotEmpty && sub.id.trim() != sourceSubGroupId) sub,
    ];
  }

  Future<void> _confirmUngroup() async {
    final detail = _detail;
    if (detail == null || _selectedPhotoIds.isEmpty || _busy) return;

    final tiles = _tiles();
    final selected =
        tiles
            .where(
              (t) => _selectedPhotoIds.contains(t.photo.id?.trim() ?? ''),
            )
            .toList();
    if (selected.isEmpty) return;

    final sources =
        selected.map((t) => t.subGroupId?.trim() ?? '').toSet();
    if (sources.length != 1) {
      AppLog.d(
        _logTag,
        'Ungroup REJECT mixed_source selected=${selected.length} '
        'sources=$sources',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select items from the same group only. Mixing main and sub-group photos is not allowed.',
          ),
        ),
      );
      return;
    }
    final sourceSubGroupId = sources.first;
    final targets = _existingTargets(sourceSubGroupId);
    final groupTitle =
        detail.name.trim().isEmpty ? 'Collection' : detail.name.trim();

    AppLog.d(
      _logTag,
      'Ungroup sheet open selected=${selected.length} '
      'source=${sourceSubGroupId.isEmpty ? 'main' : sourceSubGroupId} '
      'targets=${targets.map((t) => '${t.id}:${t.name}').join(' | ')}',
    );

    final destination = await showModalBottomSheet<BulkUngroupDestination>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Text(
                    'Move selected items to',
                    style: AppTextStyles.headline(fontSize: 17),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Text(
                    '${selected.length} selected',
                    style: AppTextStyles.caption(),
                  ),
                ),
                const SizedBox(height: 8),
                if (sourceSubGroupId.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: Text('Main group', style: AppTextStyles.body()),
                    subtitle: Text(
                      'Back into “$groupTitle” with group details',
                      style: AppTextStyles.caption(),
                    ),
                    onTap:
                        () => Navigator.of(
                          sheetContext,
                        ).pop(BulkUngroupDestination.main),
                  ),
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(
                    'Existing sub-group',
                    style: AppTextStyles.body(
                      color:
                          targets.isEmpty
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    targets.isEmpty
                        ? 'No other sub-groups available'
                        : 'Move into another Precise group in this collection',
                    style: AppTextStyles.caption(),
                  ),
                  onTap:
                      targets.isEmpty
                          ? null
                          : () => Navigator.of(
                            sheetContext,
                          ).pop(BulkUngroupDestination.existingSubgroup),
                ),
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: Text('New sub-group', style: AppTextStyles.body()),
                  subtitle: Text(
                    'Create a Precise group inside this collection',
                    style: AppTextStyles.caption(),
                  ),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(BulkUngroupDestination.newSubgroup),
                ),
                ListTile(
                  leading: const Icon(Icons.call_split_outlined),
                  title: Text('New collection', style: AppTextStyles.body()),
                  subtitle: Text(
                    'Split selected photos into a separate product',
                    style: AppTextStyles.caption(),
                  ),
                  onTap:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(BulkUngroupDestination.newCollection),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || destination == null) return;

    String? targetSubGroupId;
    var newName = '';

    if (destination == BulkUngroupDestination.existingSubgroup) {
      final target = await showModalBottomSheet<CollectionSubGroup>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: AppPadding.screenHorizontal,
                    child: Text(
                      'Choose sub-group',
                      style: AppTextStyles.headline(fontSize: 17),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...targets.map(
                    (sub) => ListTile(
                      title: Text(
                        sub.name.trim().isEmpty ? 'Sub-group' : sub.name.trim(),
                        style: AppTextStyles.body(),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(sub),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (!mounted || target == null) return;
      targetSubGroupId = target.id.trim();
    }

    if (destination == BulkUngroupDestination.newSubgroup ||
        destination == BulkUngroupDestination.newCollection) {
      final defaultName =
          destination == BulkUngroupDestination.newCollection
              ? '$groupTitle split'
              : '$groupTitle precise';
      final entered = await _promptName(
        title:
            destination == BulkUngroupDestination.newCollection
                ? 'New collection name'
                : 'New sub-group name',
        initial: defaultName,
      );
      if (!mounted || entered == null) return;
      newName = entered.trim();
      if (newName.isEmpty) return;
    }

    if (destination == BulkUngroupDestination.main &&
        sourceSubGroupId.isEmpty) {
      _setSelectMode(false);
      return;
    }

    await _runMove(
      destination: destination,
      sourceSubGroupId: sourceSubGroupId,
      photoIds: [
        for (final t in selected)
          if ((t.photo.id?.trim() ?? '').isNotEmpty) t.photo.id!.trim(),
      ],
      targetSubGroupId: targetSubGroupId,
      newName: newName,
    );
  }

  Future<String?> _promptName({
    required String title,
    required String initial,
  }) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _BrowseNameDialog(title: title, initial: initial);
      },
    );
  }

  Future<void> _runMove({
    required BulkUngroupDestination destination,
    required String sourceSubGroupId,
    required List<String> photoIds,
    String? targetSubGroupId,
    required String newName,
  }) async {
    final detail = _detail;
    if (detail == null || photoIds.isEmpty) return;

    if (destination == BulkUngroupDestination.newCollection &&
        detail.photoCount - photoIds.length < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keep at least one photo in this collection. Delete the collection instead if you want to remove everything.',
          ),
        ),
      );
      return;
    }

    final source =
        sourceSubGroupId.isEmpty
            ? <String, dynamic>{'type': 'main'}
            : <String, dynamic>{
              'type': 'subgroup',
              'subGroupId': sourceSubGroupId,
            };

    final groupSpec = ProductSpec.fromApiJson(detail.specifications?.toJson());
    // Prefer sub-group specs when moving from a precise cluster.
    ProductSpec sampleSpec = groupSpec;
    if (sourceSubGroupId.isNotEmpty) {
      for (final sub in detail.subGroups) {
        if (sub.id.trim() == sourceSubGroupId) {
          final subSpec = ProductSpec.fromApiJson(sub.specifications?.toJson());
          if (subSpec.isValid) sampleSpec = subSpec;
          break;
        }
      }
    }

    late final Map<String, dynamic> destPayload;
    switch (destination) {
      case BulkUngroupDestination.main:
        destPayload = <String, dynamic>{'type': 'main'};
      case BulkUngroupDestination.existingSubgroup:
        destPayload = <String, dynamic>{
          'type': 'existing_subgroup',
          'targetSubGroupId': targetSubGroupId!.trim(),
        };
      case BulkUngroupDestination.newSubgroup:
        destPayload = <String, dynamic>{
          'type': 'new_subgroup',
          'subGroupDetails': {
            'name': newName.trim(),
            'tag':
                sampleSpec.category.trim().isNotEmpty
                    ? sampleSpec.category.trim()
                    : (detail.tag.trim().isNotEmpty ? detail.tag.trim() : 'item'),
            'usePrecisionTag': sampleSpec.isValid,
            if (sampleSpec.isValid) 'specifications': sampleSpec.toApiJson(),
          },
        };
      case BulkUngroupDestination.newCollection:
        destPayload = <String, dynamic>{
          'type': 'new_collection',
          'collectionDetails': {
            'name': newName.trim(),
            'tag':
                sampleSpec.category.trim().isNotEmpty
                    ? sampleSpec.category.trim()
                    : (detail.tag.trim().isNotEmpty ? detail.tag.trim() : 'item'),
            'usePrecisionTag': sampleSpec.isValid,
            if (sampleSpec.isValid) 'specifications': sampleSpec.toApiJson(),
          },
        };
    }

    AppLog.d(
      _logTag,
      'API movePhotos source=$source dest=$destPayload '
      'photoIds=$photoIds revision=${detail.revision}',
    );

    setState(() => _busy = true);
    try {
      final moved = await ServiceLocator.get<CollectionRepository>().movePhotos(
        storeId: widget.storeId,
        listingId: detail.id,
        source: source,
        destination: destPayload,
        photoIds: photoIds,
        revision: detail.revision,
      );
      final newCollectionId = moved.newCollectionId?.trim();
      AppLog.d(
        _logTag,
        'OK server_move newCollectionId=${newCollectionId ?? '-'}',
      );
      if (!mounted) return;
      final createdNewCollection =
          newCollectionId != null && newCollectionId.isNotEmpty;
      if (createdNewCollection) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moved to a new collection.')),
        );
      }
      _setSelectMode(false);
      await _load(quiet: true);
      if (!mounted) return;
      // Tell store profile to refresh: source card (counts/cover) and, when
      // photos were moved into a new collection, the full grid so the new
      // listing appears without leaving and re-entering the profile.
      final product = _product;
      if (product != null) {
        _popResult = <String, Object?>{
          ...product.toMap(),
          'updated': true,
          if (createdNewCollection) 'refreshCollections': true,
          if (createdNewCollection) 'newCollectionId': newCollectionId,
        };
      } else if (createdNewCollection) {
        _popResult = <String, Object?>{
          'refreshCollections': true,
          'newCollectionId': newCollectionId,
        };
      }
    } catch (e) {
      AppLog.e(_logTag, 'FAIL server_move', e);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CatalogErrorMapper.toUserMessage(e))),
      );
    }
  }

  void _onBack() {
    Navigator.of(context).pop(_popResult);
  }

  @override
  Widget build(BuildContext context) {
    final storeTitle =
        widget.storeName.trim().isNotEmpty
            ? widget.storeName.trim()
            : (widget.pageTitle?.trim().isNotEmpty == true
                ? widget.pageTitle!.trim()
                : (widget.product.title.isEmpty
                    ? 'Collection'
                    : widget.product.title));

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _onBack();
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppPadding.screen(top: 8, bottom: 8),
                child: Row(
                  children: [
                    AppBackButton(onPressed: _onBack),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        storeTitle,
                        style: AppTextStyles.title(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_canManage && !_loading && _error == null) ...[
                      if (_selectMode) ...[
                        _BrowseToolbarAction(
                          label: 'Edit',
                          enabled: _selectedPhotoIds.isNotEmpty && !_busy,
                          onTap: _openEditSelected,
                        ),
                        _BrowseToolbarAction(
                          label: 'Ungroup',
                          enabled: _selectedPhotoIds.isNotEmpty && !_busy,
                          onTap: _confirmUngroup,
                        ),
                        _BrowseToolbarAction(
                          label: 'Done',
                          enabled: !_busy,
                          onTap: () => _setSelectMode(false),
                        ),
                      ] else
                        _BrowseToolbarAction(
                          label: 'Select',
                          enabled: !_busy,
                          onTap: () => _setSelectMode(true),
                        ),
                    ],
                  ],
                ),
              ),
              if (_selectMode && _canManage)
                Padding(
                  padding: AppPadding.screenHorizontal,
                  child: Text(
                    _busy
                        ? 'Working…'
                        : '${_selectedPhotoIds.length} selected',
                    style: AppTextStyles.caption(),
                  ),
                ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Text('Loading…', style: AppTextStyles.bodySecondary()),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppPadding.screenHorizontal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: AppTextStyles.body(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _load,
                child: Text('Retry', style: AppTextStyles.button()),
              ),
            ],
          ),
        ),
      );
    }

    final tiles = _tiles();
    final sections = _sections(tiles);
    final date = (_product ?? widget.product).addedDate;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final dateLabel = _dateLabel(dateOnly);

    return _BrowseGalleryBody(
      sections: sections,
      dateLabel: dateLabel,
      crossAxisCount: _crossAxisCount,
      selectMode: _selectMode && _canManage,
      selectedIds: _selectedPhotoIds,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onTap: (tile) {
        final id = tile.photo.id?.trim() ?? '';
        if (_selectMode && _canManage) {
          if (id.isEmpty) return;
          _toggleSelect(id);
          return;
        }
        _openPhoto(tile.photo);
      },
    );
  }
}

class _BrowseTile {
  const _BrowseTile({
    required this.photo,
    required this.sectionKey,
    required this.sectionTitle,
    required this.label,
    required this.isPrecise,
    this.subGroupId,
  });

  final CatalogPhoto photo;
  final String sectionKey;
  final String sectionTitle;
  final String label;
  final bool isPrecise;
  final String? subGroupId;
}

class _BrowseSection {
  const _BrowseSection({
    required this.key,
    required this.title,
    required this.tiles,
  });

  final String key;
  final String title;
  final List<_BrowseTile> tiles;
}

class _BrowseToolbarAction extends StatelessWidget {
  const _BrowseToolbarAction({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Text(
          label,
          style: AppTextStyles.label(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.accent : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

/// Gallery-style scroll (date + section titles + pinch columns). Keeps light theme.
class _BrowseGalleryBody extends StatelessWidget {
  const _BrowseGalleryBody({
    required this.sections,
    required this.dateLabel,
    required this.crossAxisCount,
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
    this.selectMode = false,
    this.selectedIds = const {},
  });

  final List<_BrowseSection> sections;
  final String dateLabel;
  final int crossAxisCount;
  final ValueChanged<_BrowseTile> onTap;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final bool selectMode;
  final Set<String> selectedIds;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Center(
        child: Text('Nothing to browse.', style: AppTextStyles.bodySecondary()),
      );
    }

    final singleSection = sections.length == 1;

    return RawGestureDetector(
      gestures: {
        ScaleGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
              () => ScaleGestureRecognizer(),
              (instance) {
                instance
                  ..onStart = onScaleStart
                  ..onUpdate = onScaleUpdate;
              },
            ),
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: AppPadding.screen(top: 14, bottom: 8),
              child: Text(
                singleSection
                    ? '$dateLabel  |  ${sections.first.title}'
                    : dateLabel,
                style: AppTextStyles.headline(fontSize: 18),
              ),
            ),
          ),
          for (var i = 0; i < sections.length; i++) ...[
            if (!singleSection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppPadding.screen(top: i == 0 ? 0 : 18, bottom: 8),
                  child: Text(
                    sections[i].title,
                    style: AppTextStyles.body(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 1.5,
                crossAxisSpacing: 1.5,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final tile = sections[i].tiles[index];
                final id = tile.photo.id?.trim() ?? '';
                final selected = id.isNotEmpty && selectedIds.contains(id);
                return _BrowseGalleryTile(
                  tile: tile,
                  selectMode: selectMode,
                  selected: selected,
                  onTap: () => onTap(tile),
                );
              }, childCount: sections[i].tiles.length),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _BrowseGalleryTile extends StatelessWidget {
  const _BrowseGalleryTile({
    required this.tile,
    required this.selectMode,
    required this.selected,
    required this.onTap,
  });

  final _BrowseTile tile;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: AppColors.surfaceSecondary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProductMediaImage(path: tile.photo.url),
            if (tile.isPrecise)
              Positioned(
                top: selectMode ? null : 6,
                bottom: selectMode ? 6 : null,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (selectMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        selected ? AppColors.primary : AppColors.background,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 1.4,
                    ),
                  ),
                  child:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: AppColors.textOnPrimary,
                          )
                          : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrowseNameDialog extends StatefulWidget {
  const _BrowseNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_BrowseNameDialog> createState() => _BrowseNameDialogState();
}

class _BrowseNameDialogState extends State<_BrowseNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.title, style: AppTextStyles.headline()),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppTextStyles.body(),
        decoration: InputDecoration(
          hintText: 'Name',
          hintStyle: AppTextStyles.hint(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            'Continue',
            style: AppTextStyles.label(
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}
