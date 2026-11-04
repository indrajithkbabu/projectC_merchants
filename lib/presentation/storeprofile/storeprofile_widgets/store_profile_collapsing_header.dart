import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/models/store_privacy_mode.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/appearance_scope.dart';
import 'package:project_c/helper/widgets/cart_icon_button.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/visitor_photo_selection_chrome.dart';
import 'package:project_c/services/cart_store.dart';

/// Telegram floating-capsule store profile header (pinned overlay).
///
/// Three frosted pills over the product grid (not a full-width bar):
/// back circle · identity (DP + name + followers) · actions.
/// Actions: own store → add + search; visitor browse → cart + search.
/// Visitor Import is long-press selection (forward + bottom dock), not toolbar.
class StoreProfileTelegramHeader extends StatelessWidget {
  const StoreProfileTelegramHeader({
    super.key,
    required this.state,
    required this.topPad,
    required this.onOpenStoreInfo,
    required this.onBack,
    required this.onAddProducts,
    required this.onImport,
    required this.onSearch,
    this.onCart,
    this.onDeleteSelected,
    this.selectedPhotoCount,
    this.showSelectionImport = true,
  });

  final StoreProfileState state;
  final double topPad;
  final VoidCallback onOpenStoreInfo;
  final VoidCallback onBack;
  final VoidCallback onAddProducts;
  final VoidCallback onImport;
  final VoidCallback onSearch;
  final VoidCallback? onCart;

  /// Own-store photo multi-select: replaces add/search with delete.
  final VoidCallback? onDeleteSelected;

  /// When non-null, photo multi-select chrome: close icon, subtitle shows
  /// followers · N selected. Visitor may also show forward (import).
  final int? selectedPhotoCount;

  /// False for accounts with no store of their own (Wishlist only).
  final bool showSelectionImport;

  static const double _pillHeight = 42;
  static const double _rowPad = 6;
  static const double toolbarHeight = _pillHeight + _rowPad * 2;

  /// Total overlay height (status bar + toolbar) for scroll top inset.
  static double extentFor(double topPad) => topPad + toolbarHeight;

  bool get _photoSelecting => selectedPhotoCount != null;

  /// Own store → add. Visitor browse has no toolbar Import (use long-press).
  bool get _showPrimaryAction => !_photoSelecting && state.isOwnStore;

  bool get _showSearch => !_photoSelecting && !state.isContentLocked;

  /// Visitor cart badge — browse + selection (own store hides it).
  bool get _showCart => !state.isOwnStore && onCart != null;

  /// Own-store item select → delete in the actions pill (no Cancel/Delete bar).
  bool get _showOwnerDelete =>
      _photoSelecting && state.isOwnStore && onDeleteSelected != null;

  /// Browse actions; cart / owner-delete also show during selection.
  bool get _showActionsPill =>
      _showCart ||
      _showOwnerDelete ||
      (!_photoSelecting && (_showPrimaryAction || _showSearch));

  @override
  Widget build(BuildContext context) {
    // Rebuild on Day/Night flip (AppColors is static otherwise).
    AppearanceScope.maybeOf(context);

    // Glassy capsules: translucent fill + backdrop blur; Day keeps a soft border.
    final night = AppColors.isNight;
    final pillColor =
        night
            ? AppColors.appBar.withValues(alpha: 0.42)
            : AppColors.surface.withValues(alpha: 0.55);
    final pillBorder =
        night
            ? AppColors.border.withValues(alpha: 0.45)
            : AppColors.border.withValues(alpha: 0.7);
    final onPill = night ? AppColors.textOnPrimary : AppColors.textPrimary;
    final onPillMuted =
        night
            ? AppColors.textOnPrimary.withValues(alpha: 0.72)
            : AppColors.textSecondary;

    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: SizedBox(
        height: toolbarHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppPadding.horizontal,
            _rowPad,
            AppPadding.horizontal,
            _rowPad,
          ),
          child: Row(
            children: [
              _FrostedPill(
                color: pillColor,
                borderColor: pillBorder,
                height: _pillHeight,
                child: _PillIconButton(
                  icon:
                      _photoSelecting
                          ? Icons.close_rounded
                          : Icons.arrow_back_ios_new_rounded,
                  color: onPill,
                  size: _photoSelecting ? 20 : 18,
                  tooltip: _photoSelecting ? 'Close' : 'Back',
                  onTap: onBack,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FrostedPill(
                  color: pillColor,
                  borderColor: pillBorder,
                  height: _pillHeight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      4,
                      0,
                      _photoSelecting ? 2 : 12,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _photoSelecting ? null : onOpenStoreInfo,
                            child: Row(
                              children: [
                                StoreProfileLogo(
                                  size: _pillHeight - 8,
                                  imageUrl: state.coverImageUrl,
                                  storeName: state.storeName,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.storeName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.headline(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: onPill,
                                          height: 1.15,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (!_photoSelecting &&
                                              !state.isOwnStore &&
                                              state.isPrivateStore) ...[
                                            Icon(
                                              Icons.lock_outline_rounded,
                                              size: 11,
                                              color: onPillMuted,
                                            ),
                                            const SizedBox(width: 3),
                                          ],
                                          Flexible(
                                            child: Text(
                                              _subtitleLabel(
                                                followerCount:
                                                    state.followerCount,
                                                selectedCount:
                                                    selectedPhotoCount,
                                                followLabel:
                                                    _followLabel(state),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.caption(
                                                fontSize: 12,
                                                color: onPillMuted,
                                                height: 1.15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_photoSelecting && showSelectionImport)
                          IconButton(
                            onPressed: onImport,
                            tooltip: 'Import',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 42,
                            ),
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            icon: WhatsAppForwardIcon(color: onPill, size: 22),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showActionsPill) ...[
                const SizedBox(width: 8),
                _FrostedPill(
                  color: pillColor,
                  borderColor: pillBorder,
                  height: _pillHeight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showCart)
                        _CartPillButton(
                          color: onPill,
                          onTap: onCart!,
                        ),
                      if (_showOwnerDelete)
                        _PillIconButton(
                          icon: Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 22,
                          tooltip: 'Delete',
                          onTap: onDeleteSelected!,
                        ),
                      if (_showPrimaryAction)
                        _PillIconButton(
                          icon: Icons.add_rounded,
                          color: onPill,
                          size: 22,
                          tooltip: 'Add products',
                          onTap: onAddProducts,
                        ),
                      if (_showSearch)
                        _PillIconButton(
                          icon: Icons.search_rounded,
                          color: onPill,
                          size: 22,
                          tooltip: 'Search',
                          onTap: onSearch,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _followerLabel(int count) {
    final n = count < 0 ? 0 : count;
    if (n == 1) return '1 follower';
    return '${_formatCount(n)} followers';
  }

  static String? _followLabel(StoreProfileState state) {
    if (state.isOwnStore) return null;
    if (state.followStatus.isFollowing) return 'Following';
    if (state.followStatus.isPending) return 'Requested';
    return null;
  }

  static String _subtitleLabel({
    required int followerCount,
    int? selectedCount,
    String? followLabel,
  }) {
    final followers = _followerLabel(followerCount);
    if (selectedCount != null) {
      final n = selectedCount < 0 ? 0 : selectedCount;
      final selected = n == 1 ? '1 selected' : '$n selected';
      return '$followers · $selected';
    }
    final follow = followLabel?.trim() ?? '';
    if (follow.isEmpty) return followers;
    return '$followers · $follow';
  }

  static String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
    }
    return '$n';
  }
}

class _FrostedPill extends StatelessWidget {
  const _FrostedPill({
    required this.color,
    required this.height,
    required this.child,
    this.borderColor,
  });

  final Color color;
  final Color? borderColor;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: radius,
            border:
                borderColor == null
                    ? null
                    : Border.all(color: borderColor!, width: 0.8),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(height: height, child: child),
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 42),
      // No Material splash/highlight on frosted pills.
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      icon: Icon(icon, size: size, color: color),
    );
  }
}

class _CartPillButton extends StatelessWidget {
  const _CartPillButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cart = ServiceLocator.get<CartStore>();
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final count = cart.count;
        return IconButton(
          onPressed: onTap,
          tooltip: 'Cart',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 40, height: 42),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 22, color: color),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: CartCountBadge(count: count),
                ),
            ],
          ),
        );
      },
    );
  }
}
