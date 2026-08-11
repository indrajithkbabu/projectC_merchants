import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';

/// App-wide back control — icon only, left-aligned with screen content.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.color = AppColors.accent,
    this.size = 20,
  });

  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: size,
            color: color,
          ),
        ),
      ),
    );
  }
}
