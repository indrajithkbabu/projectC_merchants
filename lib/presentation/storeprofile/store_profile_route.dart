import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_gallery/store_gallery_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/catalog_media_debug.dart';
import 'package:project_c/helper/catalog_responsive_image.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/import_qa.dart';
import 'package:project_c/helper/product_gallery_picker.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/visitor_wishlist_batch.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/helper/widgets/catalog_image_edge_fades.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/models/store_product.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/navigation/smooth_fade_page_route.dart';
import 'package:project_c/navigation/telegram_photo_page_route.dart';
import 'package:project_c/presentation/privacy/privacy_widgets/follow_requests_banner.dart';
import 'package:project_c/presentation/store_import/quick_import_flow.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/gallery_pinch_host.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/pending_uploads_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_private_content_gate.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_gallery_sliver.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_collapsing_header.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';
import 'package:project_c/services/product_view_preferences.dart';
import 'package:project_c/storage/store_profile_scroll_cache.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/wishlist/wishlist_repository.dart';

class StoreProfileRoute extends StatefulWidget {
  const StoreProfileRoute({
    super.key,
    this.focusProductId,
  });

  /// When set (e.g. from search product-details store chevron), scroll to and
  /// highlight this listing’s group card with a primary border.
  final String? focusProductId;

  @override
  State<StoreProfileRoute> createState() => _StoreProfileRouteState();
}

class _StoreProfileRouteState extends State<StoreProfileRoute> {
  final Set<String> _selectedIds = {};
  /// Visitor multi-select: `"productId|imageIndex"`.
  final Set<String> _selectedPhotoKeys = {};
  bool _selectionMode = false;
  bool _visitorPhotoSelecting = false;
  bool _visitorWishlistBusy = false;
  final GlobalKey _focusProductKey = GlobalKey();
  bool _didScrollToFocus = false;

  late final ScrollController _scrollController;
  ProductViewMode? _activeViewMode;
  /// Gallery view pinch columns (2…9); same ladder as channel Media/Gallery.
  double _galleryColumns = 4;
  String _scrollStoreId = '';
  /// True once resume is applied (or there was nothing to resume).
  bool _didRestoreScroll = false;
  bool _restorePending = false;
  int _restoreAttempts = 0;
  /// Product count last seen while restoring — extent grows as grid lays out.
  int _restoreProductCount = -1;
  /// Last maxScrollExtent while waiting for layout to grow.
  double _lastRestoreMax = -1;
  int _extentStableFrames = 0;
  /// Jump FAB visibility — ValueNotifier so toggles do not rebuild the
  /// CustomScrollView / change sliver padding mid-fling (was the main jank).
  final ValueNotifier<bool> _showJumpToBottom = ValueNotifier<bool>(false);

  /// Last offset while the position was attached (dispose often has no clients).
  double _lastKnownOffset = 0;
  /// Target from cache for this visit; kept until applied at full extent or
  /// the user clears it by scrolling to the top.
  double? _resumeTarget;
  bool _leaving = false;
  /// Hide the product list until resume jump finishes so open does not flash
  /// the top item then scroll down.
  bool _awaitingReveal = false;
  bool _revealScheduled = false;

  /// Frames to wait for extent growth before accepting a shorter list bottom.
  static const int _extentStableBeforeClamp = 8;
  static const int _maxRestoreAttempts = 90;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void deactivate() {
    // Persist before the element is unmounted (pop swipe / back). Dispose
    // alone is too late if the controller already detached at 0.
    _persistScrollBeforeLeave(reason: 'deactivate');
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _leaving = false;
  }

  @override
  void dispose() {
    _persistScrollBeforeLeave(reason: 'dispose');
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _showJumpToBottom.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _leaving) return;
    final pos = _scrollController.position;
    final pixels = pos.pixels;
    // Pop / route teardown often fires a spurious 0 offset. Ignore it so we
    // don't clobber a deep scroll position right before dispose.
    if (pixels <= 0 && _lastKnownOffset > 80) {
      StoreProfileScrollCache.log(
        'onScroll ignore spurious 0 (lastKnown=${_lastKnownOffset.toStringAsFixed(1)})',
      );
      return;
    }
    _lastKnownOffset = pixels;
    final distanceFromBottom = pos.maxScrollExtent - pixels;
    final show =
        pixels > 160 &&
        distanceFromBottom > 120 &&
        pos.maxScrollExtent > 240;
    if (show != _showJumpToBottom.value) {
      _showJumpToBottom.value = show;
    }
    // Persist only after restore attempt settled, and only real positions.
    if (_didRestoreScroll && pixels > 0) {
      _resumeTarget = pixels;
      _persistScroll(offset: pixels, reason: 'scroll');
    } else if (_didRestoreScroll && pixels <= 8 && pos.maxScrollExtent > 240) {
      // User intentionally scrolled back to the top — clear resume.
      _resumeTarget = null;
      _lastKnownOffset = 0;
      StoreProfileScrollCache.instance.clearMode(
        _scrollStoreId,
        _activeViewMode,
      );
    }
  }

  void _persistScrollBeforeLeave({required String reason}) {
    if (_leaving && reason != 'dispose') return;
    _leaving = true;
    final fromController =
        _scrollController.hasClients ? _scrollController.offset : null;
    final best = [
      _lastKnownOffset,
      _resumeTarget ?? 0,
      fromController ?? 0,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    StoreProfileScrollCache.log(
      'leave/$reason store=$_scrollStoreId mode=$_activeViewMode '
      'lastKnown=${_lastKnownOffset.toStringAsFixed(1)} '
      'resume=${_resumeTarget?.toStringAsFixed(1) ?? 'null'} '
      'controller=${fromController?.toStringAsFixed(1) ?? 'null'} '
      'best=${best.toStringAsFixed(1)}',
    );
    if (best > 0) {
      _lastKnownOffset = best;
      _persistScroll(offset: best, reason: reason);
    }
  }

  void _persistScroll({double? offset, String reason = 'persist'}) {
    final mode = _activeViewMode;
    final storeId = _scrollStoreId.trim();
    if (mode == null || storeId.isEmpty) {
      StoreProfileScrollCache.log(
        'persist SKIP reason=$reason storeEmpty=${storeId.isEmpty} modeNull=${mode == null}',
      );
      return;
    }
    final value =
        offset ??
        (_scrollController.hasClients
            ? _scrollController.offset
            : _lastKnownOffset);
    if (value <= 0) {
      if (reason != 'scroll') {
        StoreProfileScrollCache.log(
          'persist SKIP reason=$reason value<=0',
        );
      }
      return;
    }
    if (reason != 'scroll') {
      StoreProfileScrollCache.log(
        'persist reason=$reason store=$storeId mode=${mode.name} '
        'offset=${value.toStringAsFixed(1)}',
      );
    }
    StoreProfileScrollCache.instance.write(storeId, mode, value);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _applyJumpToBottomVisibility() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    final show =
        pos.pixels > 160 &&
        distanceFromBottom > 120 &&
        pos.maxScrollExtent > 240;
    if (show != _showJumpToBottom.value) {
      _showJumpToBottom.value = show;
    }
  }

  /// Telegram-style resume: jump to the last offset for this store + view mode.
  /// Skipped when [focusProductId] is driving a one-shot scroll-into-view.
  void _restoreScrollIfNeeded(
    StoreProfileState state,
    ProductViewMode viewMode,
  ) {
    final storeId = state.storeId.trim();
    if (storeId.isEmpty) return;

    if (_scrollStoreId != storeId) {
      StoreProfileScrollCache.log(
        'storeChanged $_scrollStoreId → $storeId',
      );
      _scrollStoreId = storeId;
      _didRestoreScroll = false;
      _restorePending = false;
      _restoreAttempts = 0;
      _restoreProductCount = -1;
      _lastRestoreMax = -1;
      _extentStableFrames = 0;
      _resumeTarget = null;
      _lastKnownOffset = 0;
      _leaving = false;
      _awaitingReveal = false;
      _revealScheduled = false;
    }
    if (_activeViewMode != null && _activeViewMode != viewMode) {
      StoreProfileScrollCache.log(
        'viewModeChanged $_activeViewMode → $viewMode',
      );
      if (_lastKnownOffset > 0) {
        _persistScroll(offset: _lastKnownOffset, reason: 'viewModeSwitch');
      }
      _didRestoreScroll = false;
      _restorePending = false;
      _restoreAttempts = 0;
      _restoreProductCount = -1;
      _lastRestoreMax = -1;
      _extentStableFrames = 0;
      _resumeTarget = null;
      _lastKnownOffset = 0;
      _awaitingReveal = false;
      _revealScheduled = false;
    }
    _activeViewMode = viewMode;

    final focusId = widget.focusProductId?.trim() ?? '';
    if (focusId.isNotEmpty) {
      if (!_didRestoreScroll) {
        StoreProfileScrollCache.log('skip restore — focusProductId set');
        _didRestoreScroll = true;
        _resumeTarget = null;
        _awaitingReveal = false;
      }
      return;
    }

    // Seed resume target once per store+mode visit.
    if (_resumeTarget == null && !_didRestoreScroll) {
      final saved = StoreProfileScrollCache.instance.read(storeId, viewMode);
      if (saved == null || saved <= 0) {
        StoreProfileScrollCache.log(
          'no cached offset — start at top store=$storeId mode=${viewMode.name}',
        );
        _didRestoreScroll = true;
        _awaitingReveal = false;
        return;
      }
      _resumeTarget = saved;
      // Hide list until jump lands — avoids top-then-scroll flash.
      _awaitingReveal = true;
      _revealScheduled = false;
      StoreProfileScrollCache.log(
        'seed resume=${saved.toStringAsFixed(1)} '
        'products=${state.products.length} loading=${state.isLoadingProducts} '
        'holdReveal=true',
      );
    }

    // Products/layout grew after an early clamp — re-open restore.
    final productCount = state.products.length;
    if (_resumeTarget != null &&
        _resumeTarget! > 80 &&
        productCount != _restoreProductCount) {
      _restoreProductCount = productCount;
      if (_didRestoreScroll &&
          _scrollController.hasClients &&
          _scrollController.offset + 80 < _resumeTarget!) {
        StoreProfileScrollCache.log(
          'products changed — re-apply resume '
          '(pixels=${_scrollController.offset.toStringAsFixed(1)} '
          'target=${_resumeTarget!.toStringAsFixed(1)} count=$productCount)',
        );
        _didRestoreScroll = false;
        _restoreAttempts = 0;
        // Near top after product swap — hide again; otherwise silent nudge.
        if (_scrollController.offset < 32) {
          _awaitingReveal = true;
          _revealScheduled = false;
        }
      }
    }

    // Position was reset to top (extent collapse / rebuild) — re-apply.
    // Also when the list is shorter than the saved offset (max < resume).
    if (_didRestoreScroll &&
        _resumeTarget != null &&
        _resumeTarget! > 80 &&
        _scrollController.hasClients &&
        _scrollController.offset < 32 &&
        _scrollController.position.maxScrollExtent > 240) {
      StoreProfileScrollCache.log(
        'position reset to top — re-apply resume=${_resumeTarget!.toStringAsFixed(1)} '
        'max=${_scrollController.position.maxScrollExtent.toStringAsFixed(1)}',
      );
      _didRestoreScroll = false;
      _restoreAttempts = 0;
      _lastRestoreMax = -1;
      _extentStableFrames = 0;
      _awaitingReveal = true;
      _revealScheduled = false;
    }

    // After a short-list clamp, images may grow maxScrollExtent — nudge down
    // silently (already revealed at bottom; no hold).
    if (_didRestoreScroll &&
        _resumeTarget != null &&
        _scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final pixels = _scrollController.offset;
      if (max > pixels + 80 && pixels + 80 < _resumeTarget!) {
        StoreProfileScrollCache.log(
          'extent grew after restore — nudge '
          'pixels=${pixels.toStringAsFixed(1)} max=${max.toStringAsFixed(1)} '
          'resume=${_resumeTarget!.toStringAsFixed(1)}',
        );
        _didRestoreScroll = false;
        _restoreAttempts = 0;
        _extentStableFrames = 0;
      }
    }

    if (_didRestoreScroll || _restorePending) return;
    if (_resumeTarget == null || _resumeTarget! <= 0) {
      _didRestoreScroll = true;
      return;
    }

    // Wait for first products paint before burning restore attempts.
    if (state.isLoadingProducts && state.products.isEmpty) {
      StoreProfileScrollCache.log('wait — products still loading');
      return;
    }

    _scheduleRestoreAttempt();
  }

  void _scheduleRestoreAttempt() {
    if (_restorePending) return;
    _restorePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePending = false;
      if (!mounted || _didRestoreScroll || _leaving) return;
      _tryRestoreScroll();
    });
  }

  /// After jumpTo, wait one frame (still hidden) then reveal so the first
  /// visible paint is already at the resume offset.
  void _finishRestoreAndReveal({
    required double offset,
    required String reason,
    bool persist = true,
  }) {
    _lastKnownOffset = offset;
    _didRestoreScroll = true;
    _restoreAttempts = 0;
    if (persist && offset > 0) {
      _persistScroll(offset: offset, reason: reason);
    }
    if (!_awaitingReveal) {
      _applyJumpToBottomVisibility();
      return;
    }
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _leaving) return;
      // One more silent nudge while still hidden (extent often grows 1 frame).
      if (_scrollController.hasClients && _resumeTarget != null) {
        final max = _scrollController.position.maxScrollExtent;
        final next = _resumeTarget!.clamp(0.0, max);
        if (next > _scrollController.offset + 8) {
          StoreProfileScrollCache.log(
            'restore pre-reveal JUMP to=${next.toStringAsFixed(1)} '
            'max=${max.toStringAsFixed(1)}',
          );
          _scrollController.jumpTo(next);
          _lastKnownOffset = next;
        }
      }
      if (_awaitingReveal) {
        StoreProfileScrollCache.log(
          'reveal list at=${_lastKnownOffset.toStringAsFixed(1)}',
        );
        setState(() {
          _awaitingReveal = false;
          _revealScheduled = false;
        });
      } else {
        _revealScheduled = false;
      }
      _applyJumpToBottomVisibility();
    });
  }

  void _tryRestoreScroll() {
    final saved = _resumeTarget;
    if (saved == null || saved <= 0) {
      _finishRestoreAndReveal(offset: 0, reason: 'noTarget', persist: false);
      return;
    }
    if (!_scrollController.hasClients) {
      _restoreAttempts += 1;
      StoreProfileScrollCache.log(
        'restore wait clients attempt=$_restoreAttempts',
      );
      if (_restoreAttempts < _maxRestoreAttempts) {
        _scheduleRestoreAttempt();
      } else {
        _finishRestoreAndReveal(offset: 0, reason: 'noClients', persist: false);
      }
      return;
    }

    final pos = _scrollController.position;
    final max = pos.maxScrollExtent;
    final pixels = pos.pixels;

    // Track whether layout extent is still growing (images / rows).
    if ((max - _lastRestoreMax).abs() < 1) {
      _extentStableFrames += 1;
    } else {
      _extentStableFrames = 0;
      _lastRestoreMax = max;
    }

    // Already at resume point, or already at bottom of a shorter list.
    if (pixels + 8 >= saved ||
        (max > 0 && pixels + 8 >= max && saved >= max)) {
      StoreProfileScrollCache.log(
        'restore already there pixels=${pixels.toStringAsFixed(1)} '
        'saved=${saved.toStringAsFixed(1)} max=${max.toStringAsFixed(1)}',
      );
      _finishRestoreAndReveal(offset: pixels, reason: 'alreadyThere');
      return;
    }

    if (max <= 0) {
      _restoreAttempts += 1;
      if (_restoreAttempts < _maxRestoreAttempts) {
        _scheduleRestoreAttempt();
      } else {
        StoreProfileScrollCache.log(
          'restore give-up empty extent — keep target for next rebuild',
        );
        _restoreAttempts = 0;
        // Don't leave the screen blank forever.
        if (_awaitingReveal) {
          _finishRestoreAndReveal(offset: 0, reason: 'emptyExtent', persist: false);
        }
      }
      return;
    }

    // Jump to min(saved, max). When the list is shorter than when left
    // (logs: max=2583 saved=2979), that is the current bottom — do not wait
    // forever for an extent that will never arrive.
    final target = saved.clamp(0.0, max);
    final shortList = max + 8 < saved;
    final extentSettled =
        !shortList || _extentStableFrames >= _extentStableBeforeClamp;

    if (shortList && !extentSettled) {
      // Progressive: pin to current bottom while layout may still grow.
      // List stays hidden (_awaitingReveal) so interim jumps are invisible.
      if (pixels + 8 < max) {
        StoreProfileScrollCache.log(
          'restore interim JUMP to max=${max.toStringAsFixed(1)} '
          'saved=${saved.toStringAsFixed(1)} stable=$_extentStableFrames',
        );
        _scrollController.jumpTo(max);
        _lastKnownOffset = max;
      } else if (_restoreAttempts <= 6 || _restoreAttempts % 15 == 0) {
        StoreProfileScrollCache.log(
          'restore wait growth attempt=$_restoreAttempts '
          'max=${max.toStringAsFixed(1)} saved=${saved.toStringAsFixed(1)} '
          'stable=$_extentStableFrames',
        );
      }
      _restoreAttempts += 1;
      if (_restoreAttempts < _maxRestoreAttempts) {
        _scheduleRestoreAttempt();
      } else {
        StoreProfileScrollCache.log(
          'restore finalize short list at max=${max.toStringAsFixed(1)}',
        );
        _finishRestoreAndReveal(offset: max, reason: 'restoreShortList');
      }
      return;
    }

    if (target <= 0) {
      _finishRestoreAndReveal(offset: 0, reason: 'zeroTarget', persist: false);
      return;
    }

    StoreProfileScrollCache.log(
      'restore JUMP to=${target.toStringAsFixed(1)} '
      'saved=${saved.toStringAsFixed(1)} max=${max.toStringAsFixed(1)} '
      'was=${pixels.toStringAsFixed(1)} shortList=$shortList',
    );
    _scrollController.jumpTo(target);
    // Keep original saved target so a later taller layout can nudge further.
    if (!shortList) {
      _resumeTarget = target;
    }
    _finishRestoreAndReveal(offset: target, reason: 'restoreJump');
  }

  void _exitSelection() {
    if (!_selectionMode &&
        _selectedIds.isEmpty &&
        _selectedPhotoKeys.isEmpty) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _visitorPhotoSelecting = false;
      _selectedIds.clear();
      _selectedPhotoKeys.clear();
    });
  }

  void _enterSelection(StoreProduct product) {
    setState(() {
      _selectionMode = true;
      _visitorPhotoSelecting = false;
      _selectedPhotoKeys.clear();
      _selectedIds
        ..clear()
        ..add(product.id);
    });
  }

  void _enterVisitorPhotoSelection(StoreProduct product, int imageIndex) {
    if (product.importSelectionBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exclusive piece — cannot be re-imported'),
        ),
      );
      return;
    }
    setState(() {
      _selectionMode = true;
      _visitorPhotoSelecting = true;
      _selectedIds.clear();
      _selectedPhotoKeys
        ..clear()
        ..add(StoreProductGrid.photoKey(product.id, imageIndex));
    });
  }

  void _toggleSelected(StoreProduct product) {
    setState(() {
      if (_selectedIds.contains(product.id)) {
        _selectedIds.remove(product.id);
        if (_selectedIds.isEmpty) {
          _selectionMode = false;
          _visitorPhotoSelecting = false;
        }
      } else {
        _selectedIds.add(product.id);
      }
    });
  }

  void _toggleVisitorPhoto(StoreProduct product, int imageIndex) {
    final key = StoreProductGrid.photoKey(product.id, imageIndex);
    if (!_selectedPhotoKeys.contains(key) &&
        product.importSelectionBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exclusive piece — cannot be re-imported'),
        ),
      );
      return;
    }
    setState(() {
      if (_selectedPhotoKeys.contains(key)) {
        _selectedPhotoKeys.remove(key);
        if (_selectedPhotoKeys.isEmpty) {
          _selectionMode = false;
          _visitorPhotoSelecting = false;
        }
      } else {
        _selectedPhotoKeys.add(key);
      }
    });
  }

  Future<void> _addProducts(BuildContext context) async {
    // Telegram gallery → WhatsApp compose (edit + title) → group form.
    ProductGalleryPickResult pick = ProductGalleryPickResult.empty;
    try {
      pick = await ProductGalleryPicker.pickImages(
        context,
        includeCamera: true,
        confirmAsSend: true,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open image picker right now.')),
      );
      return;
    }
    if (!context.mounted || pick.paths.isEmpty) return;

    final storeId = context.read<StoreProfileBloc>().state.storeId;
    // Continue hero warm during route push (picker may already have started).
    final heroIdx =
        pick.initialIndex.clamp(0, pick.paths.length - 1);
    final heroPath = pick.paths[heroIdx];
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = MediaQuery.sizeOf(context).width;
    final cacheWidth = ProductGalleryPicker.composeHeroDecodeWidth(
      logicalWidth: logicalW,
      dpr: dpr,
    );
    unawaited(
      precacheImage(
        ResizeImage(
          FileImage(File(heroPath)),
          width: cacheWidth,
        ),
        context,
      ).then((_) {}, onError: (Object _, StackTrace __) {}),
    );
    assert(() {
      debugPrint(
        '[ComposeNavPerf] compose_route_push n=${pick.paths.length}',
      );
      return true;
    }());
    final composed = await Navigator.of(context).pushNamed(
      Routes.addProductComposeRoute,
      arguments: <String, Object?>{
        'imagePaths': pick.paths,
        'storeId': storeId,
        'initialIndex': pick.initialIndex,
      },
    );
    if (!context.mounted || composed is! Map) return;

    final published = await Navigator.of(context).pushNamed(
      Routes.addProductGroupRoute,
      arguments: Map<String, Object?>.from(composed),
    );
    if (!context.mounted) return;
    if (published is Map) {
      final payload = Map<String, Object?>.from(published);
      // Background upload already started — shimmer is driven by coordinator.
      if (payload['uploading'] == true) return;
      context.read<StoreProfileBloc>().add(
        StoreProfileProductPublished(StoreProduct.fromMap(payload)),
      );
      return;
    }
    // Done may popUntil store profile (result is null). Background upload
    // shimmers via coordinator; avoid a full-grid reload shimmer.
  }

  Future<void> _openCollectionBrowse(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
  ) async {
    StoreProduct media = product;
    for (final p in state.productsForMedia) {
      if (p.id == product.id) {
        media = p;
        break;
      }
    }
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls(
      ProductImagePaths.displayable(media.imagePaths),
      cacheWidth: CatalogImageCache.gridCacheWidth(),
    );
    final result = await Navigator.of(context).pushNamed(
      Routes.collectionBrowseRoute,
      arguments: <String, Object?>{
        'product': media,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
      },
    );
    if (!context.mounted || result is! Map) return;

    final payload = Map<String, Object?>.from(result);
    if (payload['deleted'] == true) {
      final productId = payload['productId'] as String?;
      if (productId == null || productId.isEmpty) return;
      context.read<StoreProfileBloc>().add(
        StoreProfileProductDeleted(productId),
      );
      return;
    }

    // Ungroup → new collection (and similar structural moves): reload the grid
    // so the new listing appears and the source card counts/cover stay in sync.
    final newCollectionId = (payload['newCollectionId'] as String?)?.trim();
    if (payload['refreshCollections'] == true ||
        (newCollectionId != null && newCollectionId.isNotEmpty)) {
      context.read<StoreProfileBloc>().add(const StoreProfileLoadCollections());
      return;
    }

    if (payload['updated'] == true && payload.containsKey('id')) {
      _applyProductUpdatedPayload(context, payload);
    }
  }

  Future<void> _openProductDetails(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product, {
    int imageIndex = 0,
    Rect? sourceRect,
    ProductViewMode? viewMode,
  }) async {
    StoreProduct media = product;
    for (final p in state.productsForMedia) {
      if (p.id == product.id) {
        media = p;
        break;
      }
    }

    final galleryState = StoreGalleryState(
      products: state.productsForMedia,
      storeName: state.storeName,
      storeLink: state.storeLink,
      storeId: state.storeId,
      isOwnStore: state.isOwnStore,
      sections: StoreGalleryState.buildSections(state.productsForMedia),
    );
    final feed = galleryState.buildPhotoFeed();
    final feedIndex = galleryState.feedIndexFor(
      productId: media.id,
      imageIndex: imageIndex,
    );

    final paths = ProductImagePaths.displayable(media.imagePaths);
    final safeIndex =
        imageIndex < 0
            ? 0
            : (imageIndex >= media.imagePaths.length ? 0 : imageIndex);
    final masterAt =
        media.imagePaths.isEmpty ? '' : media.imagePaths[safeIndex];
    // Flyer matches painted tile (Group/Single per-cell size; Gallery=cols).
    final mode = viewMode ?? _activeViewMode ?? ProductViewMode.gallery;
    final paintRole = () {
      if (mode == ProductViewMode.gallery) {
        return CatalogResponsiveImage.roleForMediaColumns(
          _galleryColumns.round(),
        );
      }
      final displayIndexes = <int>[
        for (var i = 0; i < media.imagePaths.length; i++)
          if (ProductImagePaths.isDisplayable(media.imagePaths[i])) i,
      ];
      final collageIndex = displayIndexes.indexOf(safeIndex);
      return CatalogResponsiveImage.roleForCollageCell(
        imageCount: displayIndexes.length,
        imageIndex: collageIndex < 0 ? 0 : collageIndex,
      );
    }();
    final paintedPath =
        ProductImagePaths.isDisplayable(masterAt)
            ? media.urlForRole(safeIndex, paintRole)
            : '';
    final photoPath =
        paintedPath.isNotEmpty
            ? paintedPath
            : (paths.isEmpty ? null : paths.first);
    final photoThumbhash = media.thumbhashAt(safeIndex);
    final masterPath =
        ProductImagePaths.isDisplayable(masterAt)
            ? media.urlForRole(safeIndex, CatalogImageRole.zoom, log: true)
            : '';
    if (masterPath.isNotEmpty) {
      CatalogMediaDebug.qualityTapOpen(
        from: 'store_profile_${(viewMode ?? _activeViewMode)?.name ?? "?"}',
        role: CatalogImageRole.zoom,
        url: masterPath,
        paintedUrl: photoPath,
      );
    }

    final result = await Navigator.of(context).pushNamed(
      Routes.productDetailsRoute,
      arguments: <String, Object?>{
        'product': media,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'storeId': state.storeId,
        'isOwnStore': state.isOwnStore,
        'imageIndex': imageIndex,
        'galleryFeed': feed,
        'galleryFeedIndex': feedIndex,
        if (sourceRect != null &&
            photoPath != null &&
            photoPath.trim().isNotEmpty) ...{
          'photoSourceRect': rectToArgs(sourceRect),
          'photoPath': photoPath,
          if (photoThumbhash != null && photoThumbhash.isNotEmpty)
            'photoThumbhash': photoThumbhash,
        },
      },
    );
    if (!context.mounted || result is! Map) return;

    final payload = Map<String, Object?>.from(result);
    if (payload['deleted'] == true) {
      final productId = payload['productId'] as String?;
      if (productId == null || productId.isEmpty) return;
      context.read<StoreProfileBloc>().add(
        StoreProfileProductDeleted(productId),
      );
      return;
    }

    if (payload['updated'] == true && payload.containsKey('id')) {
      _applyProductUpdatedPayload(context, payload);
    }
  }

  /// Merge details pop into the grid. [silent] = counts only (no snack).
  void _applyProductUpdatedPayload(
    BuildContext context,
    Map<String, Object?> payload,
  ) {
    final incoming = StoreProduct.fromMap(payload);
    final silent = payload['silent'] == true;
    var product = incoming;
    if (silent) {
      // Keep collage / title from the grid card; only bump count badges.
      final products = context.read<StoreProfileBloc>().state.products;
      for (final p in products) {
        if (p.id == incoming.id) {
          product = p.copyWith(
            likeCount: incoming.likeCount,
            viewCount: incoming.viewCount ?? p.viewCount,
            wishlistCount: incoming.wishlistCount,
            clearWishlistCount:
                incoming.wishlistCount == null &&
                payload.containsKey('wishlistCount'),
          );
          break;
        }
      }
    }
    context.read<StoreProfileBloc>().add(
      StoreProfileProductUpdated(
        product,
        replacedListingId: payload['replacedListingId'] as String?,
        silent: silent,
      ),
    );
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            count == 1 ? 'Delete product?' : 'Delete $count products?',
            style: AppTextStyles.headline(fontSize: 18),
          ),
          content: Text(
            count == 1
                ? 'This removes the selected product from your store. Linked imports in other stores will also stop showing it.'
                : 'This removes the selected products from your store. Linked imports in other stores will also stop showing them.',
            style: AppTextStyles.body(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: AppTextStyles.button()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: AppTextStyles.button(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (!context.mounted || confirmed != true) return;
    final ids = _selectedIds.toList();
    _exitSelection();
    context.read<StoreProfileBloc>().add(StoreProfileProductsDeleted(ids));
  }

  Future<void> _openStoreChannel(
    BuildContext context,
    StoreProfileState state,
  ) async {
    final imageUrls = <String>[
      for (final photo in state.storeImages)
        if (photo.url.trim().isNotEmpty) photo.url.trim(),
    ];
    if (imageUrls.isEmpty) {
      final cover = state.coverImageUrl.trim();
      if (cover.isNotEmpty) imageUrls.add(cover);
    }
    final products = state.productsForMedia;
    // Prefetch Media densest tier (thumbnail) before push; channel also warms
    // detailUrl when cols ≤ 5.
    final mediaGridUrls = <String>[
      for (final product in products)
        for (var i = 0; i < product.imagePaths.length; i++)
          if (ProductImagePaths.isDisplayable(product.imagePaths[i]))
            product.urlForRole(i, CatalogImageRole.grid),
    ];
    // ignore: unawaited_futures
    CatalogImageCache.precacheUrls([
      ...imageUrls,
      ...mediaGridUrls,
    ]);
    // ignore: unawaited_futures
    CatalogImageCache.warmWindow(
      urls: mediaGridUrls,
      firstIndex: 0,
      lastIndex: CatalogImageCache.mediaGridWarmCount(columns: 9) - 1,
      cacheWidth: CatalogImageCache.gridCacheWidth(),
      concurrency: 12,
    );
    await Navigator.of(context).pushNamed(
      Routes.storeChannelRoute,
      arguments: <String, Object?>{
        'storeId': state.storeId,
        'storeName': state.storeName,
        'storeLink': state.storeLink,
        'imageUrls': imageUrls,
        'products': products,
        'followerCount': state.followerCount,
        'followingCount': state.followingCount,
        'productCount': state.productCount,
        'isOwnStore': state.isOwnStore,
        // Keep follow actions live on the channel screen.
        'profileBloc': context.read<StoreProfileBloc>(),
      },
    );
  }

  void _openStoreSearch(BuildContext context, StoreProfileState state) {
    Navigator.of(context).pushNamed(
      Routes.storeSearchRoute,
      arguments: <String, Object?>{
        'storeId': state.storeId,
        'storeName': state.storeName,
        'productCount': state.productCount,
      },
    );
  }

  void _openImport(BuildContext context, StoreProfileState state) {
    if (!state.canImport) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create your store before importing products.'),
        ),
      );
      return;
    }
    if (state.isOwnStore) {
      Navigator.of(context).pushNamed(Routes.storeListingRoute);
      return;
    }
    Navigator.of(context)
        .pushNamed(
          Routes.storeImportSelectRoute,
          arguments: <String, Object?>{
            'storeId': state.storeId,
            'storeName': state.storeName,
            'storeLink': state.storeLink,
            'products': state.productsForMedia,
            'avatarColor': state.avatarColor,
          },
        )
        .then((_) {
          if (!context.mounted) return;
          context.read<StoreProfileBloc>().add(
            const StoreProfileProbeImportAvailability(),
          );
        });
  }

  void _onProductInteraction(
    BuildContext context,
    StoreProfileState state,
    StoreProduct product,
    ProductViewMode viewMode, {
    int imageIndex = 0,
    Rect? sourceRect,
  }) {
    if (_visitorPhotoSelecting) {
      _toggleVisitorPhoto(product, imageIndex);
      return;
    }
    if (_selectionMode) {
      _toggleSelected(product);
      return;
    }
    // Group view: gallery-style collection browse (Select / Edit / Ungroup).
    // Single / Gallery: open the tapped collage/gallery photo in product details.
    if (viewMode == ProductViewMode.group) {
      _openCollectionBrowse(context, state, product);
      return;
    }
    _openProductDetails(
      context,
      state,
      product,
      imageIndex: imageIndex,
      sourceRect: sourceRect,
      viewMode: viewMode,
    );
  }

  void _scheduleScrollToFocus(StoreProfileState state) {
    final focusId = widget.focusProductId?.trim() ?? '';
    if (focusId.isEmpty || _didScrollToFocus) return;
    if (!state.products.any((p) => p.id == focusId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToFocus) return;
      final ctx = _focusProductKey.currentContext;
      if (ctx == null) return;
      _didScrollToFocus = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.18,
      );
    });
  }

  Widget _productsSliver({
    required StoreProfileState state,
    required ProductViewMode viewMode,
    bool attachFocusKey = true,
    double galleryColumns = 4,
    bool galleryPinching = false,
  }) {
    if (state.isContentLocked) {
      if (state.isLoadingStoreMeta) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
        );
      }
      return SliverToBoxAdapter(
        child: StorePrivateContentGate(
          storeName: state.storeName,
          followStatus: state.followStatus,
        ),
      );
    }

    final canSelect = state.isOwnStore;
    final canVisitorPhotoSelect =
        !state.isOwnStore && !state.isContentLocked;
    final deletingId = state.deletingProductId;
    final deletingIds =
        deletingId == null || deletingId.isEmpty
            ? <String>{}
            : <String>{deletingId};
    final focusId = widget.focusProductId?.trim() ?? '';
    final focusProductId = focusId.isEmpty ? null : focusId;
    final focusKey =
        attachFocusKey && focusProductId != null ? _focusProductKey : null;
    final pending = state.pendingUploads;

    if (attachFocusKey) {
      _scheduleScrollToFocus(state);
    }

    final productsSliver =
        viewMode == ProductViewMode.gallery
            ? StoreProductGallerySliver(
              products: state.productsForMedia,
              isLoading: state.isLoadingProducts && pending.isEmpty,
              selectionMode: _selectionMode && !_visitorPhotoSelecting,
              photoSelectionMode: _visitorPhotoSelecting,
              selectedIds: _selectedIds,
              selectedPhotoKeys: _selectedPhotoKeys,
              columns: galleryColumns,
              pinching: galleryPinching,
              focusProductId: focusProductId,
              focusKey: focusKey,
              onImageTap:
                  (product, imageIndex, {Rect? sourceRect}) =>
                      _onProductInteraction(
                        context,
                        state,
                        product,
                        viewMode,
                        imageIndex: imageIndex,
                        sourceRect: sourceRect,
                      ),
              onProductLongPress:
                  canSelect ? (product) => _enterSelection(product) : null,
              onImageLongPress:
                  canVisitorPhotoSelect
                      ? (product, imageIndex) {
                        if (_visitorPhotoSelecting) {
                          _toggleVisitorPhoto(product, imageIndex);
                        } else {
                          _enterVisitorPhotoSelection(product, imageIndex);
                        }
                      }
                      : null,
            )
            : StoreProductGrid(
              products: state.products,
              viewMode: viewMode,
              selectionMode: _selectionMode && !_visitorPhotoSelecting,
              photoSelectionMode: _visitorPhotoSelecting,
              selectedIds: _selectedIds,
              selectedPhotoKeys: _selectedPhotoKeys,
              deletingProductIds: deletingIds,
              listingAvailability: state.listingAvailability,
              focusProductId: focusProductId,
              focusKey: focusKey,
              onRemoveSourceDeleted:
                  state.isOwnStore
                      ? (product) => context.read<StoreProfileBloc>().add(
                        StoreProfileProductsDeleted([product.id]),
                      )
                      : null,
              onProductTap:
                  (product, imageIndex, {Rect? sourceRect}) =>
                      _onProductInteraction(
                        context,
                        state,
                        product,
                        viewMode,
                        imageIndex: imageIndex,
                        sourceRect: sourceRect,
                      ),
              onProductLongPress:
                  canSelect ? (product) => _enterSelection(product) : null,
              onImageLongPress:
                  canVisitorPhotoSelect
                      ? (product, imageIndex) {
                        if (_visitorPhotoSelecting) {
                          _toggleVisitorPhoto(product, imageIndex);
                        } else {
                          _enterVisitorPhotoSelection(product, imageIndex);
                        }
                      }
                      : null,
            ).buildSliver(
              isLoading: state.isLoadingProducts && pending.isEmpty,
            );

    if (pending.isEmpty) return productsSliver;

    return SliverMainAxisGroup(
      slivers: [
        PendingUploadsSliver(pending: pending, viewMode: viewMode),
        if (viewMode != ProductViewMode.gallery)
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        productsSliver,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPrefs = ServiceLocator.get<ProductViewPreferences>();
    return MultiBlocListener(
      listeners: [
        BlocListener<StoreProfileBloc, StoreProfileState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<StoreProfileBloc>().add(
              const StoreProfileClearMessage(),
            );
          },
        ),
        BlocListener<StoreProfileBloc, StoreProfileState>(
          listenWhen:
              (prev, curr) =>
                  curr.infoMessage != null &&
                  curr.infoMessage != prev.infoMessage,
          listener: (context, state) {
            final message = state.infoMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<StoreProfileBloc>().add(
              const StoreProfileClearMessage(),
            );
          },
        ),
      ],
      child: PopScope(
        canPop: !_selectionMode && !_visitorPhotoSelecting,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_selectionMode || _visitorPhotoSelecting) {
            _exitSelection();
          }
        },
        child: EdgeBackSwipe(
          onBack: () async => _goHome(context),
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
            // Images scroll under the home indicator; docks pad themselves.
            extendBodyBehindBottom: true,
        child: BlocBuilder<StoreProfileBloc, StoreProfileState>(
              // Skip rebuilds that don't affect the discover listing chrome.
              buildWhen:
                  (prev, curr) =>
                      prev.storeId != curr.storeId ||
                      prev.products != curr.products ||
                      prev.productsDetailed != curr.productsDetailed ||
                      prev.pendingUploads != curr.pendingUploads ||
                      prev.isLoadingProducts != curr.isLoadingProducts ||
                      prev.isOwnStore != curr.isOwnStore ||
                      prev.canViewContent != curr.canViewContent ||
                      prev.followStatus != curr.followStatus ||
                      prev.isFollowBusy != curr.isFollowBusy ||
                      prev.showFollowRequestsBanner !=
                          curr.showFollowRequestsBanner ||
                      prev.pendingFollowRequestCount !=
                          curr.pendingFollowRequestCount ||
                      prev.followRequestPreviewNames !=
                          curr.followRequestPreviewNames ||
                      prev.storeName != curr.storeName ||
                      prev.followerCount != curr.followerCount ||
                      prev.apiProductCount != curr.apiProductCount ||
                      prev.privacy != curr.privacy ||
                      prev.viewerHasOwnStore != curr.viewerHasOwnStore ||
                      prev.coverImageUrl != curr.coverImageUrl ||
                      prev.storeImages != curr.storeImages ||
                      prev.deletingProductId != curr.deletingProductId ||
                      prev.errorMessage != curr.errorMessage ||
                      prev.infoMessage != curr.infoMessage,
          builder: (context, state) {
                return ListenableBuilder(
                  listenable: viewPrefs,
                  builder: (context, _) {
                    final viewMode = viewPrefs.mode;
                    // Discover listing for owner and visitor (no owner bottom
                    // nav — Wishlist / My store / Activity live on the main
                    // shell / home header).
                    _restoreScrollIfNeeded(state, viewMode);
                    return _buildDiscoverBody(
                      context: context,
                            state: state,
                      viewMode: viewMode,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Product list scroll; Gallery mode wraps with Media-style 2…9 pinch.
  Widget _buildDiscoverScroll({
    required BuildContext context,
    required StoreProfileState state,
    required ProductViewMode viewMode,
    required bool attachFocusKey,
    required double scrollTop,
    required double chromeBottom,
  }) {
    Widget scroll({
      required double galleryColumns,
      required bool galleryPinching,
    }) {
      return CustomScrollView(
        controller: _scrollController,
        // Larger cache + clamping/bouncing = smoother Telegram-like fling.
        cacheExtent: 1800,
        physics:
            galleryPinching
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
        slivers: [
          if (state.showFollowRequestsBanner)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppPadding.horizontal,
                  scrollTop,
                  AppPadding.horizontal,
                  12,
                ),
                child: FollowRequestsBanner(
                  pendingCount: state.pendingFollowRequestCount,
                  previewNames: state.followRequestPreviewNames,
                  onTap: () => _openFollowRequests(context, state),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              top: state.showFollowRequestsBanner ? 0 : scrollTop,
              bottom: chromeBottom,
            ),
            sliver: _productsSliver(
              state: state,
              viewMode: viewMode,
              attachFocusKey: attachFocusKey,
              galleryColumns: galleryColumns,
              galleryPinching: galleryPinching,
            ),
          ),
        ],
      );
    }

    if (viewMode != ProductViewMode.gallery) {
      return scroll(galleryColumns: 4, galleryPinching: false);
    }

    return GalleryPinchHost(
      initialColumns: _galleryColumns,
      onColumnsChanged: (cols) {
        // Keep for tap flyer URL; GalleryPinchHost already rebuilds tiles.
        _galleryColumns = cols.toDouble();
      },
      builder: (context, columns, pinching) {
        return scroll(
          galleryColumns: columns,
          galleryPinching: pinching,
        );
      },
    );
  }

  /// Listing-first store profile (Discover + visitors). Telegram header tap
  /// opens [Routes.storeChannelRoute]. Grid scrolls under the translucent bar.
  Widget _buildDiscoverBody({
    required BuildContext context,
    required StoreProfileState state,
    required ProductViewMode viewMode,
    bool attachFocusKey = true,
  }) {
    final topPad = ScreenWrapper.statusBarTop(context);
    final headerExtent = StoreProfileTelegramHeader.extentFor(topPad);
    // Owner delete selection bar sits under the Telegram header.
    // Visitor photo select uses the header itself (close · DP · count).
    const selectionBarBlock = 56.0;
    final scrollTop =
        headerExtent +
        (_selectionMode && !_visitorPhotoSelecting ? selectionBarBlock : 0);
    // Prefer viewPadding — body extends under the home indicator.
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    // Visitor photo select → Import / Wishlist dock (hides Follow while active).
    final showVisitorActionDock = _visitorPhotoSelecting;
    const visitorActionDockHeight = 52.0;
    // Visitor not following → glassy Follow / Requested dock at bottom.
    final showFollowDock =
        !showVisitorActionDock &&
        !state.isOwnStore &&
        (state.followStatus == StoreFollowStatus.none ||
            state.followStatus.isPending);
    const followDockHeight = 52.0;
    const followDockGap = 12.0;
    const jumpSize = 44.0;
    final bottomDockHeight =
        showVisitorActionDock
            ? visitorActionDockHeight
            : (showFollowDock ? followDockHeight : 0.0);
    final bottomDockGap =
        bottomDockHeight > 0 ? followDockGap : 0.0;
    // Raise jump above the bottom edge; stack above Follow / visitor dock.
    final jumpBottom =
        bottomDockHeight > 0
            ? safeBottom + 16 + bottomDockHeight + bottomDockGap
            : safeBottom + 96;
    // Only reserve dock space — never toggle list padding when the jump FAB
    // appears (that forced sliver relayout mid-fling and killed smoothness).
    final chromeBottom =
        bottomDockHeight > 0
            ? 16 + bottomDockHeight + bottomDockGap
            : jumpSize + 8.0;

    return Stack(
      children: [
        // Full-bleed image grid — scrolls under status bar / home indicator.
        // Opacity 0 while resume jumps — layout still runs so maxScrollExtent
        // is real; first visible frame is already at the saved offset.
        Opacity(
          opacity: _awaitingReveal ? 0 : 1,
          child: IgnorePointer(
            ignoring: _awaitingReveal,
            child: _buildDiscoverScroll(
              context: context,
              state: state,
              viewMode: viewMode,
              attachFocusKey: attachFocusKey,
              scrollTop: scrollTop,
              chromeBottom: chromeBottom,
            ),
          ),
        ),
        if (!_awaitingReveal) const CatalogImageEdgeFades(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: StoreProfileTelegramHeader(
            state: state,
            topPad: topPad,
            selectedPhotoCount:
                _visitorPhotoSelecting ? _selectedPhotoKeys.length : null,
            onOpenStoreInfo: () => _openStoreChannel(context, state),
            onBack: () => _goHome(context),
            onAddProducts: () => _addProducts(context),
            // Selection: forward (= Import). Browse: toolbar download import.
            onImport:
                _visitorPhotoSelecting
                    ? () => _onVisitorSelectionImport(state)
                    : () => _openImport(context, state),
            onSearch: () => _openStoreSearch(context, state),
            showSelectionImport: state.canImport,
          ),
        ),
        if (_selectionMode && !_visitorPhotoSelecting)
          Positioned(
            top: headerExtent,
            left: 0,
            right: 0,
            child: Material(
              color: AppColors.background.withValues(alpha: 0.96),
              child: Padding(
                padding: AppPadding.screenHorizontal,
                child: _SelectionBar(
                  count: _selectedIds.length,
                  onCancel: _exitSelection,
                  onDelete:
                      _selectedIds.isEmpty
                          ? null
                          : () => _confirmDeleteSelected(context),
                ),
              ),
            ),
          ),
        if (_visitorPhotoSelecting)
          Builder(
            builder: (context) {
              final split = visitorImportSelectionSplit(
                photoKeys: _selectedPhotoKeys,
                products: [...state.products, ...state.productsForMedia],
              );
              return VisitorPhotoSelectionOverlay(
                onImport:
                    state.canImport
                        ? () => _onVisitorSelectionImport(state)
                        : null,
                onWishlist: _onVisitorSelectionWishlist,
                wishlistBusy: _visitorWishlistBusy,
                showImport: state.canImport,
                importCount: _selectedPhotoKeys.length,
                importInstantCount: split.instant,
                importPendingCount: split.pending,
              );
            },
          ),
        Positioned(
          right: AppPadding.horizontal,
          bottom: jumpBottom,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showJumpToBottom,
            builder: (context, show, child) {
              return IgnorePointer(
                ignoring: !show,
                child: AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: child,
                ),
              );
            },
            child: _JumpToBottomButton(onTap: _scrollToBottom),
          ),
        ),
        if (showFollowDock)
          Positioned(
            left: AppPadding.horizontal,
            right: AppPadding.horizontal,
            bottom: safeBottom + 16,
            child: _GlassFollowDock(
              isPending: state.followStatus.isPending,
              isBusy: state.isFollowBusy,
              onFollow:
                  () => context.read<StoreProfileBloc>().add(
                    const StoreProfileFollowPressed(),
                  ),
              onCancelRequest:
                  () => context.read<StoreProfileBloc>().add(
                    const StoreProfileUnfollowPressed(),
                  ),
            ),
          ),
      ],
    );
  }

  /// Selection Import opens compose review; Send posts `POST …/imports`.
  Future<void> _onVisitorSelectionImport(StoreProfileState state) async {
    final products = [...state.products, ...state.productsForMedia];
    final split = visitorImportSelectionSplit(
      photoKeys: _selectedPhotoKeys,
      products: products,
    );
    ImportQa.step(
      'Dock Import tap',
      detail:
          'selected=${_selectedPhotoKeys.length} '
          'instant=${split.instant} pending=${split.pending} '
          'source=${state.storeId}',
    );
    final opened = await QuickImportFlow.openFromSelection(
      context: context,
      photoKeys: Set<String>.from(_selectedPhotoKeys),
      products: products,
      sourceStoreId: state.storeId,
      sourceStoreName: state.storeName,
      canImport: state.canImport,
    );
    if (!mounted || !opened) return;
    setState(() {
      _selectedPhotoKeys.clear();
      _selectedIds.clear();
      _selectionMode = false;
      _visitorPhotoSelecting = false;
    });
  }

  /// Private wishlist bookmark for selected cards (viewer wishlist badge).
  Future<void> _onVisitorSelectionWishlist() async {
    if (_visitorWishlistBusy || _selectedPhotoKeys.isEmpty) return;
    final bloc = context.read<StoreProfileBloc>();

    setState(() => _visitorWishlistBusy = true);
    try {
      final outcome = await VisitorWishlistBatch.wishlistSelected(
        wishlist: ServiceLocator.get<WishlistRepository>(),
        photoKeys: _selectedPhotoKeys,
        products: bloc.state.products,
        storeId: bloc.state.storeId,
      );
      if (!mounted) return;
      final next = VisitorWishlistBatch.applyWishlistCounts(
        products: bloc.state.products,
        newlyAddedProductIds: outcome.newlyAddedProductIds,
      );
      bloc.add(StoreProfileProductsReplaced(next, silent: true));
      setState(() {
        _selectedPhotoKeys.clear();
        _selectionMode = false;
        _visitorPhotoSelecting = false;
        _visitorWishlistBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _visitorWishlistBusy = false);
      final msg = CatalogErrorMapper.toUserMessage(e).trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty
                ? 'Could not update wishlist. Please try again.'
                : msg,
        ),
      ),
    );
  }
}

  /// Back from owner tabs / visitor header → store listing home.
  void _goHome(BuildContext context) {
    if (_selectionMode) {
      _exitSelection();
      return;
    }
    // Capture offset before the route starts tearing down (swipe/back).
    _persistScrollBeforeLeave(reason: 'goHome');
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.storeListingRoute,
      (route) => false,
    );
  }

  Future<void> _openFollowRequests(
    BuildContext context,
    StoreProfileState state,
  ) async {
    await Navigator.of(context).pushNamed(
      Routes.followRequestsRoute,
      arguments: {
        'storeId': state.storeId,
        'storeName': state.storeName,
      },
    );
    if (!context.mounted) return;
    context.read<StoreProfileBloc>().add(
      const StoreProfileLoadFollowRequestPreviews(),
    );
    context.read<StoreProfileBloc>().add(const StoreProfileLoadStoreMeta());
  }
}

/// Shared glass fill/border used by header-matching floating chrome.
({Color fill, Color border, Color foreground}) _glassChrome() {
  final night = AppColors.isNight;
  return (
    fill:
        night
            ? AppColors.appBar.withValues(alpha: 0.42)
            : AppColors.surface.withValues(alpha: 0.55),
    border:
        night
            ? AppColors.border.withValues(alpha: 0.45)
            : AppColors.border.withValues(alpha: 0.7),
    foreground: night ? AppColors.textOnPrimary : AppColors.textPrimary,
  );
}

/// Telegram-style floating control to jump to the end of the product list.
class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final chrome = _glassChrome();
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chrome.fill,
                border: Border.all(color: chrome.border, width: 0.8),
              ),
        child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 28,
                  color: chrome.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassy Follow / Requested dock for visitors who are not following yet.
class _GlassFollowDock extends StatelessWidget {
  const _GlassFollowDock({
    required this.isPending,
    required this.isBusy,
    required this.onFollow,
    required this.onCancelRequest,
  });

  final bool isPending;
  final bool isBusy;
  final VoidCallback onFollow;
  final VoidCallback onCancelRequest;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final chrome = _glassChrome();
    // Follow = translucent blue glass; Requested stays neutral glass.
    final blue =
        AppColors.isNight ? AppColors.accent : AppColors.primary;
    final fill =
        isPending
            ? chrome.fill
            : blue.withValues(alpha: isBusy ? 0.48 : 0.72);
    final border =
        isPending ? chrome.border : blue.withValues(alpha: 0.85);
    final foreground =
        isPending ? chrome.foreground : AppColors.textOnPrimary;
    final label = isPending ? 'Requested' : 'Follow';
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: isBusy ? null : (isPending ? onCancelRequest : onFollow),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: DecoratedBox(
                    decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: border, width: 0.8),
              ),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: Center(
                  child:
                      isBusy
                          ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: foreground,
                            ),
                          )
                          : Text(
                            label,
                            style: AppTextStyles.button(color: foreground),
                    ),
                  ),
                ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
      color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              TextButton(
                onPressed: onCancel,
                child: Text(
                  'Cancel',
                  style: AppTextStyles.body(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  count == 0
                      ? 'Select products'
                      : '$count selected',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: onDelete,
                child: Text(
                  'Delete',
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w700,
                    color:
                        onDelete == null
                            ? AppColors.textSecondary
                            : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

