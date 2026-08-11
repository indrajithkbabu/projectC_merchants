import 'package:flutter/material.dart';
import 'package:project_c/helper/widgets/primary_button.dart';

/// Continue / CTA bar that sits above [CustomNumericKeypad].
class KeypadCtaBar extends StatelessWidget {
  const KeypadCtaBar({
    super.key,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 8, 15, 12),
      child: PrimaryButton(
        label: label,
        enabled: enabled,
        isLoading: isLoading,
        onPressed: onPressed,
      ),
    );
  }
}
