import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/country_model.dart';

class CountryPickerRoute extends StatefulWidget {
  const CountryPickerRoute({
    super.key,
    this.initialIsoCode,
  });

  final String? initialIsoCode;

  @override
  State<CountryPickerRoute> createState() => _CountryPickerRouteState();
}

class _CountryPickerRouteState extends State<CountryPickerRoute> {
  late final List<Country> _all;
  late List<Country> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _all = CountryService().getAll()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    _filtered = List<Country>.from(_all);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<Country>.from(_all);
        return;
      }
      _filtered = _all.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.countryCode.toLowerCase().contains(q) ||
            c.phoneCode.contains(q) ||
            '+${c.phoneCode}'.contains(q);
      }).toList();
    });
  }

  void _select(Country country) {
    Navigator.of(context).pop(CountryModel.fromCountry(country));
  }

  @override
  Widget build(BuildContext context) {
    final selectedIso = widget.initialIsoCode;

    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: ScreenWrapper.statusBarTop(context) + 4,
            ),
            child: Padding(
              padding: AppPadding.screenHorizontal,
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Select country',
                      style: AppTextStyles.headline(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: AppPadding.screen(top: 8, bottom: 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: AppTextStyles.body(),
              decoration: InputDecoration(
                hintText: 'Search name or code',
                hintStyle: AppTextStyles.hint(fontSize: 15),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: AppTextStyles.bodySecondary(),
                    ),
                  )
                : ListView.separated(
                    padding: AppPadding.screenHorizontal,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 56,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, index) {
                      final country = _filtered[index];
                      final isSelected = country.countryCode == selectedIso;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => _select(country),
                        leading: Text(
                          country.flagEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          country.name,
                          style: AppTextStyles.body(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '+${country.phoneCode}',
                          style: AppTextStyles.caption(),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
