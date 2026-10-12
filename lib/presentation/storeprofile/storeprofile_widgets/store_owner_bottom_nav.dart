import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';

enum StoreOwnerNavTab { discover, activity, wishlist, myStore }

/// Owner-only floating capsule on [StoreProfileRoute] (PDF: Discover ·
/// Activity · Wishlist · My store). Visitors never see this bar.
///
/// Does not replace main-shell tabs. Own-store shell uses
/// Stores · Contacts · Wishlist · My store (Settings under My store).
class StoreOwnerBottomNavBar extends StatelessWidget {
  const StoreOwnerBottomNavBar({
    super.key,
    required this.current,
    required this.onChanged,
    this.activityBadgeCount = 0,
  });

  final StoreOwnerNavTab current;
  final ValueChanged<StoreOwnerNavTab> onChanged;
  final int activityBadgeCount;

  static double reservedHeight(BuildContext context) =>
      FloatingBottomNavBar.reservedHeight(context);

  @override
  Widget build(BuildContext context) {
    final items = <({StoreOwnerNavTab tab, String label, IconData icon})>[
      (
        tab: StoreOwnerNavTab.discover,
        label: 'Discover',
        icon: Icons.search_rounded,
      ),
      (
        tab: StoreOwnerNavTab.activity,
        label: 'Activity',
        icon: Icons.notifications_none_rounded,
      ),
      (
        tab: StoreOwnerNavTab.wishlist,
        label: 'Wishlist',
        icon: Icons.favorite_border_rounded,
      ),
      (
        tab: StoreOwnerNavTab.myStore,
        label: 'My store',
        icon: Icons.storefront_outlined,
      ),
    ];

    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        FloatingBottomNavBar.horizontalInset,
        0,
        FloatingBottomNavBar.horizontalInset,
        FloatingBottomNavBar.bottomGap + bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navBar,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.navBarBorder),
          boxShadow: [
            if (!AppColors.isNight)
              BoxShadow(
                color: AppColors.navBarShadow,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: SizedBox(
          height: FloatingBottomNavBar.barHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _OwnerNavItem(
                    label: items[i].label,
                    icon: items[i].icon,
                    selected: current == items[i].tab,
                    badgeCount:
                        items[i].tab == StoreOwnerNavTab.activity
                            ? activityBadgeCount
                            : 0,
                    onTap: () => onChanged(items[i].tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerNavItem extends StatelessWidget {
  const _OwnerNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppColors.navBarActive : AppColors.navBarInactive;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 24, color: color),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
