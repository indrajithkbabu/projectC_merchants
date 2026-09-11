import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_import/store_import_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/presentation/store_import/store_import_navigation.dart';

class StoreImportApprovedRoute extends StatelessWidget {
  const StoreImportApprovedRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenWrapper(
      backgroundColor: AppColors.background,
      statusBarIconBrightness: Brightness.dark,
      child: BlocBuilder<StoreImportBloc, StoreImportState>(
        builder: (context, state) {
          final count = state.importedCount;
          final storeName = state.sourceStore.name;

          return Padding(
            padding: AppPadding.screen(
              top: ScreenWrapper.statusBarTop(context) + 24,
              bottom: 24,
            ),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Import approved',
                  style: AppTextStyles.title(fontSize: 28),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    style: AppTextStyles.bodySecondary(),
                    children: [
                      TextSpan(
                        text: '$count products',
                        style: AppTextStyles.body(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' from $storeName are now live in your store.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'View my store',
                  onPressed: () {
                    navigateToOwnStoreProfile(
                      context,
                      fallbackStoreId: state.selectedDestinationId,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
