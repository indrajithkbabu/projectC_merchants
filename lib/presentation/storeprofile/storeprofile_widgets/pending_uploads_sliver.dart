import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/product_image.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/ui_sounds.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/models/pending_product_upload.dart';
import 'package:project_c/models/product_view_mode.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/product_image_collage.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_product_grid_shimmer.dart';

/// Telegram-style placeholders for in-flight create uploads.
///
/// While uploading/committing: collage previews + per-photo **loader**.
/// After commit success: stagger **checks** (with bubble tick sound) then
/// swap to the real product. On API failure: **close** icons; tap retries.
class PendingUploadsSliver extends StatelessWidget {
  const PendingUploadsSliver({
    super.key,
    required this.pending,
    required this.viewMode,
    this.galleryCrossAxisCount = 4,
  });

  final List<PendingProductUpload> pending;
  final ProductViewMode viewMode;
  final int galleryCrossAxisCount;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    // Warm pool once while pending tiles are on screen.
    unawaited(UiSounds.warmBubbleTick());
    if (pending.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return switch (viewMode) {
      ProductViewMode.gallery => _gallerySliver(context),
      ProductViewMode.single || ProductViewMode.group => _gridSliver(),
    };
  }

  Widget _gridSliver() {
    final delegate =
        viewMode == ProductViewMode.single
            ? StoreProductGrid.singleDelegate
            : StoreProductGrid.groupDelegate;
    return SliverGrid(
      gridDelegate: delegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) => _PendingUploadCard(
          pending: pending[index],
          large: viewMode == ProductViewMode.single,
        ),
        childCount: pending.length,
      ),
    );
  }

  Widget _gallerySliver(BuildContext context) {
    final slivers = <Widget>[];
    for (final item in pending) {
      final photos = _visiblePhotos(item);
      final count = photos.isNotEmpty
          ? photos.length
          : (item.photoCount < 1 ? 1 : item.photoCount);
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Text(
              item.hasFailed
                  ? (item.title.trim().isEmpty
                      ? 'Upload failed · tap to retry'
                      : '${item.title.trim()} · tap to retry')
                  : (item.title.trim().isEmpty ? 'Uploading…' : item.title),
              style: AppTextStyles.headline(
                fontSize: 16,
                color:
                    item.hasFailed ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
      Widget grid;
      if (photos.isEmpty) {
        grid = GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: galleryCrossAxisCount,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: count,
          itemBuilder: (context, index) => item.hasFailed
              ? const _FailedCloseTile()
              : const _PendingShimmerFallback(),
        );
      } else {
        grid = _PendingRevealHost(
          pending: item,
          builder: (revealed) {
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: galleryCrossAxisCount,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return _PendingPhotoTile(
                  slot: photos[index],
                  showCheck: revealed.contains(index),
                  revealing: item.isRevealing,
                  forceFailed: item.hasFailed,
                );
              },
            );
          },
        );
      }
      slivers.add(
        SliverToBoxAdapter(
          child: _PendingInteractionShell(pending: item, child: grid),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    return SliverMainAxisGroup(slivers: slivers);
  }
}

List<PendingPhotoSlot> _visiblePhotos(PendingProductUpload pending) {
  if (pending.photos.isNotEmpty) return pending.photos;
  return const [];
}

List<int> _tickableIndexes(List<PendingPhotoSlot> photos) {
  return [
    for (var i = 0; i < photos.length; i++)
      if (photos[i].status != PendingPhotoStatus.failed) i,
  ];
}

/// Blocks taps while uploading; on failure, tap retries the API call.
class _PendingInteractionShell extends StatelessWidget {
  const _PendingInteractionShell({
    required this.pending,
    required this.child,
  });

  final PendingProductUpload pending;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (pending.hasFailed) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          context.read<StoreProfileBloc>().add(
            StoreProfilePendingUploadRetry(pending.id),
          );
        },
        child: child,
      );
    }
    return AbsorbPointer(child: child);
  }
}

/// Drives one-by-one tick reveal after [PendingProductUpload.isRevealing].
class _PendingRevealHost extends StatefulWidget {
  const _PendingRevealHost({
    required this.pending,
    this.child,
    this.builder,
  }) : assert(child != null || builder != null);

  final PendingProductUpload pending;
  final Widget? child;
  final Widget Function(Set<int> revealedIndexes)? builder;

  @override
  State<_PendingRevealHost> createState() => _PendingRevealHostState();
}

class _PendingRevealHostState extends State<_PendingRevealHost> {
  final Set<int> _revealed = <int>{};
  Timer? _timer;
  var _finishScheduled = false;
  var _finishDispatched = false;
  late final StoreProfileBloc _bloc;
  late String _pendingId;

  static const _tickMs = 140;
  static const _holdAfterLastMs = 220;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<StoreProfileBloc>();
    _pendingId = widget.pending.id;
    unawaited(UiSounds.warmBubbleTick());
    if (widget.pending.isRevealing && !widget.pending.hasFailed) {
      _startReveal();
    }
  }

  @override
  void didUpdateWidget(covariant _PendingRevealHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pending.hasFailed) {
      _timer?.cancel();
      _revealed.clear();
      _finishScheduled = false;
      return;
    }
    if (!oldWidget.pending.isRevealing && widget.pending.isRevealing) {
      _startReveal();
    }
    if (oldWidget.pending.id != widget.pending.id) {
      _timer?.cancel();
      _revealed.clear();
      _finishScheduled = false;
      _finishDispatched = false;
      _pendingId = widget.pending.id;
      if (widget.pending.isRevealing && !widget.pending.hasFailed) {
        _startReveal();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.pending.isRevealing &&
        !widget.pending.hasFailed &&
        !_finishDispatched) {
      _finishDispatched = true;
      _bloc.add(StoreProfilePendingRevealFinished(_pendingId));
    }
    super.dispose();
  }

  void _startReveal() {
    _timer?.cancel();
    _revealed.clear();
    _finishScheduled = false;
    _finishDispatched = false;
    final photos = _visiblePhotos(widget.pending);
    final order = _tickableIndexes(photos);
    if (order.isEmpty) {
      _scheduleFinish();
      return;
    }
    var step = 0;
    void tick() {
      if (!mounted || widget.pending.hasFailed) return;
      if (step >= order.length) {
        _scheduleFinish();
        return;
      }
      setState(() => _revealed.add(order[step]));
      UiSounds.playBubbleTick();
      step++;
      if (step >= order.length) {
        _scheduleFinish();
      } else {
        _timer = Timer(const Duration(milliseconds: _tickMs), tick);
      }
    }

    _timer = Timer(const Duration(milliseconds: 60), tick);
  }

  void _scheduleFinish() {
    if (_finishScheduled || widget.pending.hasFailed) return;
    _finishScheduled = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: _holdAfterLastMs), () {
      if (_finishDispatched || widget.pending.hasFailed) return;
      _finishDispatched = true;
      _bloc.add(StoreProfilePendingRevealFinished(_pendingId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.builder;
    if (builder != null) {
      return builder(Set<int>.from(_revealed));
    }
    return widget.child!;
  }
}

class _PendingUploadCard extends StatelessWidget {
  const _PendingUploadCard({
    required this.pending,
    required this.large,
  });

  final PendingProductUpload pending;
  final bool large;

  @override
  Widget build(BuildContext context) {
    AppearanceScope.maybeOf(context);
    final photos = _visiblePhotos(pending);
    final paths = <String>[
      for (final slot in photos)
        if (slot.paintPath.isNotEmpty) slot.paintPath,
    ];
    final hashes = <String>[
      for (final slot in photos) slot.thumbhash.trim(),
    ];

    return _PendingInteractionShell(
      pending: pending,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: AppColors.surfaceSecondary,
          child: _PendingRevealHost(
            pending: pending,
            builder: (revealed) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (paths.isEmpty)
                    pending.hasFailed
                        ? const _FailedCloseTile()
                        : const _PendingShimmerFallback()
                  else
                    ProductImageCollage(
                      imagePaths: paths,
                      imageThumbhashes: hashes,
                      layoutIdentity: 'pending_${pending.id}_${paths.length}',
                      cellOverlayBuilder: (index) {
                        if (index < 0 || index >= photos.length) {
                          return const SizedBox.shrink();
                        }
                        return _UploadStatusOverlay(
                          status: photos[index].status,
                          showCheck: revealed.contains(index),
                          revealing: pending.isRevealing,
                          forceFailed: pending.hasFailed,
                        );
                      },
                    ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Text(
                        pending.hasFailed
                            ? (pending.title.trim().isEmpty
                                ? 'Tap to retry'
                                : '${pending.title.trim()} · Tap to retry')
                            : (pending.title.trim().isEmpty
                                ? ''
                                : pending.title.trim()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption(
                          fontSize: large ? 13 : 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PendingPhotoTile extends StatelessWidget {
  const _PendingPhotoTile({
    required this.slot,
    required this.showCheck,
    required this.revealing,
    required this.forceFailed,
  });

  final PendingPhotoSlot slot;
  final bool showCheck;
  final bool revealing;
  final bool forceFailed;

  @override
  Widget build(BuildContext context) {
    final path = slot.paintPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path.isEmpty)
          ColoredBox(color: AppColors.surfaceSecondary)
        else
          ProductMediaImage(
            path: path,
            thumbhash: slot.thumbhash,
            fit: BoxFit.cover,
          ),
        _UploadStatusOverlay(
          status: slot.status,
          showCheck: showCheck,
          revealing: revealing,
          forceFailed: forceFailed,
        ),
      ],
    );
  }
}

class _FailedCloseTile extends StatelessWidget {
  const _FailedCloseTile();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSecondary,
      child: const _UploadStatusOverlay(
        status: PendingPhotoStatus.failed,
        showCheck: false,
        revealing: false,
        forceFailed: true,
      ),
    );
  }
}

/// Loader until commit; staggered checks after success; close on failure.
class _UploadStatusOverlay extends StatelessWidget {
  const _UploadStatusOverlay({
    required this.status,
    required this.showCheck,
    required this.revealing,
    this.forceFailed = false,
  });

  final PendingPhotoStatus status;
  final bool showCheck;
  final bool revealing;
  final bool forceFailed;

  @override
  Widget build(BuildContext context) {
    final showFail = forceFailed || status == PendingPhotoStatus.failed;
    final showTick = !showFail && revealing && showCheck;
    final showLoader = !showFail && !showTick;

    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.18),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.overlayBadge,
            ),
            alignment: Alignment.center,
            child: showFail
                ? Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: AppColors.textOnPrimary,
                  )
                : showTick
                    ? Icon(
                        Icons.check_rounded,
                        size: 22,
                        color: AppColors.textOnPrimary,
                      )
                    : showLoader
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.textOnPrimary,
                            ),
                          )
                        : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _PendingShimmerFallback extends StatefulWidget {
  const _PendingShimmerFallback();

  @override
  State<_PendingShimmerFallback> createState() =>
      _PendingShimmerFallbackState();
}

class _PendingShimmerFallbackState extends State<_PendingShimmerFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ProductUploadShimmerTile(t: _controller.value),
    );
  }
}
