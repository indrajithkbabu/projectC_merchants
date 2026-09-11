import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

enum FloatingNavTab { stores, contacts, settings, profile }

class FloatingNavItem {
  const FloatingNavItem({
    required this.tab,
    required this.label,
    required this.icon,
    this.activeIcon,
    this.badgeCount,
    this.avatar,
  });

  final FloatingNavTab tab;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final int? badgeCount;
  final Widget? avatar;
}

/// Telegram-style floating capsule bottom navigation.
class FloatingBottomNavBar extends StatelessWidget {
  const FloatingBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
  });

  final List<FloatingNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Content should leave this much space above the system inset.
  static const double barHeight = 64;
  static const double horizontalInset = 16;
  static const double bottomGap = 10;

  static double reservedHeight(BuildContext context) {
    // Hide reserved space while the IME is open (nav is animated away).
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return 8;
    }
    return barHeight + bottomGap + MediaQuery.paddingOf(context).bottom;
  }

  /// Whether the soft keyboard is currently visible.
  static bool isKeyboardVisible(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        bottomGap + bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.navBar,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.navBarBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.navBarShadow,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItemButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemButton extends StatelessWidget {
  const _NavItemButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.navBarInactive;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color:
                    selected ? AppColors.navBarActivePill : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  item.avatar ??
                      Icon(
                        selected
                            ? (item.activeIcon ?? item.icon)
                            : item.icon,
                        size: 22,
                        color: color,
                      ),
                  if (item.badgeCount != null && item.badgeCount! > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: _Badge(count: item.badgeCount!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: AppTextStyles.caption(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navBar, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.caption(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}
