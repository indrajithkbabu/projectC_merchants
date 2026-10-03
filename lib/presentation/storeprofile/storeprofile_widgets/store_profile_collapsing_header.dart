import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_actions_row.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';

/// Pinned store profile header.
///
/// Defaults to the compact bar (listing-first). Tap the compact identity to
/// expand store details; tap the header again (or scroll the product list) to
/// collapse. Expand progress is driven by [expandT] from the parent animation.
class StoreProfileCollapsingHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  StoreProfileCollapsingHeaderDelegate({
    required this.state,
    required this.expandT,
    required this.onToggleDetails,
    required this.onBack,
    required this.onAddProducts,
    required this.onImport,
    required this.onSearch,
    required this.onAddMembers,
    required this.onCopyStoreLink,
    this.onViewAll,
    this.onManageImages,
  });

  final StoreProfileState state;

  /// 0 = compact (listing-first), 1 = full store details.
  final double expandT;
  final VoidCallback onToggleDetails;
  final VoidCallback onBack;
  final VoidCallback onAddProducts;
  final VoidCallback onImport;
  final VoidCallback onSearch;
  final VoidCallback? onAddMembers;
  final VoidCallback onCopyStoreLink;
  final VoidCallback? onViewAll;
  final VoidCallback? onManageImages;

  static const _toolbarHeight = 52.0;
  static const _expandedTopGap = 12.0;
  /// Fits logo, name, link, members/products row.
  static const _headerCardHeightBase = 212.0;
  /// Compact Add member row (text + light vertical padding).
  static const _headerCardAddMemberExtra = 30.0;
  static const _actionsGap = 18.0;
  static const _actionsHeight = 48.0;
  static const _productsTopGap = 16.0;
  static const _productsHeight = 18.0;
  static const _productsBottomGap = 10.0;
  static const _compactLogo = 36.0;

  double get _headerCardHeight =>
      _headerCardHeightBase +
      (onAddMembers != null ? _headerCardAddMemberExtra : 0);

  double get _collapsedExtent =>
      _toolbarHeight + _productsTopGap + _productsHeight + _productsBottomGap;

  double get _expandedExtra {
    final actionsExtra =
        state.showActionsRow ? (_actionsGap + _actionsHeight) : 0.0;
    return _expandedTopGap + _headerCardHeight + actionsExtra;
  }

  /// Own store → blue add. Other store (when importable) → blue download.
  bool get _showPrimaryAction =>
      state.isOwnStore || (!state.isOwnStore && state.canImport);

  @override
  double get minExtent => _collapsedExtent + (_expandedExtra * expandT);

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = expandT.clamp(0.0, 1.0);
    // Stagger fades so compact identity and expanded details cross smoothly.
    final compactT = Curves.easeInOutCubic.transform(
      (1.0 - ((t - 0.08) / 0.55).clamp(0.0, 1.0)),
    );
    final expandedT = Curves.easeOutCubic.transform(
      ((t - 0.05) / 0.7).clamp(0.0, 1.0),
    );
    final actionsT = Curves.easeOutCubic.transform(
      ((t - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    final detailsHeight = _expandedExtra * t;
    final showExpanded = detailsHeight > 0.5 && expandedT > 0.02;

    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (showExpanded)
            Positioned(
              top: _toolbarHeight,
              left: 0,
              right: 0,
              height: detailsHeight,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: _expandedExtra,
                  child: IgnorePointer(
                    ignoring: expandedT < 0.05,
                    child: Opacity(
                      opacity: expandedT,
                      child: Padding(
                        padding: const EdgeInsets.only(top: _expandedTopGap),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StoreProfileHeaderCard(
                              state: state,
                              onAddMembers: onAddMembers,
                              onCopyStoreLink: onCopyStoreLink,
                              onToggleDetails: onToggleDetails,
                              onManageImages: onManageImages,
                            ),
                            if (state.showActionsRow && actionsT > 0.02) ...[
                              const SizedBox(height: _actionsGap),
                              IgnorePointer(
                                ignoring: actionsT < 0.5,
                                child: Opacity(
                                  opacity: actionsT,
                                  child: StoreProfileActionsRow(
                                    isOwnStore: state.isOwnStore,
                                    canImport: state.canImport,
                                    onAddProducts: onAddProducts,
                                    onImport: onImport,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _toolbarHeight,
            child: ColoredBox(
              color: AppColors.background,
              child: Row(
                children: [
                  AppBackButton(onPressed: onBack),
                  Expanded(
                    child: GestureDetector(
                      onTap: onToggleDetails,
                      behavior: HitTestBehavior.opaque,
                      child: IgnorePointer(
                        ignoring: compactT < 0.05,
                        child: Opacity(
                          opacity: compactT,
                          child: _CompactStoreIdentity(state: state),
                        ),
                      ),
                    ),
                  ),
                  if (_showPrimaryAction)
                    ClipRect(
                      child: SizedBox(
                        // Collapse width with compactT so the icon only shows
                        // when the header is not expanded (actions row covers it).
                        width: 40 * compactT.clamp(0.0, 1.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Opacity(
                            opacity: compactT,
                            child: IgnorePointer(
                              ignoring: compactT < 0.5,
                              child: _PrimaryToolbarButton(
                                icon:
                                    state.isOwnStore
                                        ? Icons.add_rounded
                                        : Icons.file_download_outlined,
                                onTap:
                                    state.isOwnStore
                                        ? onAddProducts
                                        : onImport,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: _ToolbarIconButton(
                      icon: Icons.search_rounded,
                      onTap: onSearch,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _productsBottomGap,
            child: Row(
              children: [
                Text(
                  'PRODUCTS · ${state.productCount}',
                  style: AppTextStyles.caption(fontWeight: FontWeight.w700),
                ),
                if (onViewAll != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 12,
                    color: AppColors.divider,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onViewAll,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      'View all',
                      style: AppTextStyles.caption(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant StoreProfileCollapsingHeaderDelegate oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.expandT != expandT ||
        (oldDelegate.onViewAll == null) != (onViewAll == null) ||
        (oldDelegate.onManageImages == null) != (onManageImages == null);
  }
}

class _CompactStoreIdentity extends StatelessWidget {
  const _CompactStoreIdentity({required this.state});

  final StoreProfileState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StoreProfileLogo(
          size: StoreProfileCollapsingHeaderDelegate._compactLogo,
          imageUrl: state.coverImageUrl,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.storeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headline(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Blue circular primary action (add products / import).
class _PrimaryToolbarButton extends StatelessWidget {
  const _PrimaryToolbarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.textOnPrimary),
        ),
      ),
    );
  }
}

/// Muted circular toolbar action (search).
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
