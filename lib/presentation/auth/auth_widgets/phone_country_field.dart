import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/models/country_model.dart';

class PhoneCountryField extends StatelessWidget {
  const PhoneCountryField({
    super.key,
    required this.country,
    required this.onTap,
  });

  final CountryModel country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (country.flagEmoji != null) ...[
                Text(country.flagEmoji!, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  country.name,
                  style: AppTextStyles.body(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                country.dialCode,
                style: AppTextStyles.label(color: AppColors.textSecondary),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
