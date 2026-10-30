import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';

/// Shared home-shell tab title row (Stores / Contacts / Wishlist).
///
/// Keeps title **Y-position and height** identical across tabs so IndexedStack
/// switches do not jump. Matches the 40px trailing-action row on Stores.
/// Trailing actions stay **right-aligned** (Expanded title cluster + trailing).
class ShellTabTitleBar extends StatelessWidget {
  const ShellTabTitleBar({
    super.key,
    required this.title,
    this.titleBadge,
    this.trailing,
  });

  final String title;

  /// Optional pill / count shown immediately after the title (e.g. Wishlist).
  final Widget? titleBadge;
  final Widget? trailing;

  /// Status bar + 8 — same top inset on every shell home tab.
  static double topInset(BuildContext context) =>
      ScreenWrapper.statusBarTop(context) + 8;

  static const double bottomInset = 8;
  static const double rowHeight = 40;
  static const double titleSize = 22;

  /// Outer padding for a header block that starts with this title bar.
  static EdgeInsets padding(BuildContext context) =>
      AppPadding.screen(top: topInset(context), bottom: bottomInset);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title + optional count stay flush-left together; trailing stays
          // right-aligned. Do not put a lone Flexible around the title alone
          // (that expands and parks the badge mid-row).
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTextStyles.headline(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (titleBadge != null) ...[
                    const SizedBox(width: 8),
                    titleBadge!,
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
