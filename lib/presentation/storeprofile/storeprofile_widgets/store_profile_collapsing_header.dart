import 'package:flutter/material.dart';
import 'package:project_c/bloc/storeprofile/store_profile_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_actions_row.dart';
import 'package:project_c/presentation/storeprofile/storeprofile_widgets/store_profile_header_card.dart';

class StoreProfileCollapsingHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  StoreProfileCollapsingHeaderDelegate({
    required this.state,
    required this.onBack,
    required this.onAddProducts,
    required this.onImport,
    required this.onAddMembers,
    required this.onCopyStoreLink,
    required this.toolbarActions,
    this.onViewAll,
  });

  final StoreProfileState state;
  final VoidCallback onBack;
  final VoidCallback onAddProducts;
  final VoidCallback onImport;
  final VoidCallback? onAddMembers;
  final VoidCallback onCopyStoreLink;
  final List<Widget> toolbarActions;
  final VoidCallback? onViewAll;

  static const _toolbarHeight = 52.0;
  static const _expandedTopGap = 12.0;
  static const _headerCardHeight = 200.0;
  static const _actionsGap = 18.0;
  static const _actionsHeight = 48.0;
  static const _productsTopGap = 16.0;
  static const _productsHeight = 18.0;
  static const _productsBottomGap = 10.0;
  static const _compactLogo = 36.0;

  @override
  double get minExtent =>
      _toolbarHeight + _productsTopGap + _productsHeight + _productsBottomGap;

  @override
  double get maxExtent =>
      _toolbarHeight +
      _expandedTopGap +
      _headerCardHeight +
      _actionsGap +
      _actionsHeight +
      _productsTopGap +
      _productsHeight +
      _productsBottomGap;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final t = (shrinkOffset / range).clamp(0.0, 1.0);
    final compactT = Curves.easeInOutCubic.transform(
      ((t - 0.38) / 0.62).clamp(0.0, 1.0),
    );
    final expandedT = Curves.easeOut.transform(
      (1 - (t / 0.72).clamp(0.0, 1.0)),
    );
    final actionsT = Curves.easeOut.transform(
      (1 - (t / 0.42).clamp(0.0, 1.0)),
    );
    final addT = state.isOwnStore ? compactT : 0.0;
    final productsBlock = _productsTopGap + _productsHeight + _productsBottomGap;
    final headerHeight = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final clipHeight = headerHeight - _toolbarHeight - productsBlock;
    final showExpanded = clipHeight > 0.5 && expandedT > 0.02;

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
              bottom: productsBlock,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: maxExtent,
                  child: IgnorePointer(
                    ignoring: expandedT < 0.05,
                    child: Opacity(
                      opacity: expandedT,
                      child: Transform.translate(
                        offset: Offset(0, _expandedTopGap - shrinkOffset),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StoreProfileHeaderCard(
                              state: state,
                              onAddMembers: onAddMembers,
                              onCopyStoreLink: onCopyStoreLink,
                            ),
                            if (actionsT > 0.02) ...[
                              const SizedBox(height: _actionsGap),
                              IgnorePointer(
                                ignoring: actionsT < 0.5,
                                child: Opacity(
                                  opacity: actionsT,
                                  child: StoreProfileActionsRow(
                                    isOwnStore: state.isOwnStore,
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
                    child: IgnorePointer(
                      ignoring: compactT < 0.05,
                      child: Opacity(
                        opacity: compactT,
                        child: _CompactStoreIdentity(state: state),
                      ),
                    ),
                  ),
                  if (state.isOwnStore)
                    ClipRect(
                      child: SizedBox(
                        width: 44 * addT,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Opacity(
                            opacity: addT,
                            child: IgnorePointer(
                              ignoring: addT < 0.5,
                              child: _ToolbarIconButton(
                                icon: Icons.add_rounded,
                                onTap: onAddProducts,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (toolbarActions.isNotEmpty) const SizedBox(width: 8),
                  ...toolbarActions,
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
        oldDelegate.toolbarActions.length != toolbarActions.length ||
        (oldDelegate.onViewAll == null) != (onViewAll == null);
  }
}

class _CompactStoreIdentity extends StatelessWidget {
  const _CompactStoreIdentity({required this.state});

  final StoreProfileState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const StoreProfileLogo(size: StoreProfileCollapsingHeaderDelegate._compactLogo),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headline(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                state.storeLink,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

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
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
