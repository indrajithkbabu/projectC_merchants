import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

class StoreProfileActionsRow extends StatelessWidget {
  const StoreProfileActionsRow({
    super.key,
    required this.onAddProducts,
    required this.onImport,
    this.isOwnStore = true,
  });

  final VoidCallback onAddProducts;
  final VoidCallback onImport;
  final bool isOwnStore;

  @override
  Widget build(BuildContext context) {
    if (!isOwnStore) {
      return SizedBox(
        width: double.infinity,
        child: _ActionButton(
          label: 'Import products',
          icon: Icons.file_download_outlined,
          isPrimary: true,
          onTap: onImport,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Add products',
            icon: Icons.add_rounded,
            isPrimary: true,
            onTap: onAddProducts,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Import',
            icon: Icons.file_download_outlined,
            isPrimary: false,
            onTap: onImport,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: isPrimary ? AppColors.textOnPrimary : AppColors.accent,
        ),
        label: Text(
          label,
          style: AppTextStyles.label(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isPrimary ? AppColors.textOnPrimary : AppColors.accent,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              isPrimary ? AppColors.primary : AppColors.surfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
