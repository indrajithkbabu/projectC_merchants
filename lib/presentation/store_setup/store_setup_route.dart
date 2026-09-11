import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_setup/store_setup_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/store_setup/store_setup_widgets/store_link_card.dart';
import 'package:project_c/presentation/store_setup/store_setup_widgets/store_name_field.dart';

class StoreSetupRoute extends StatefulWidget {
  const StoreSetupRoute({super.key});

  @override
  State<StoreSetupRoute> createState() => _StoreSetupRouteState();
}

class _StoreSetupRouteState extends State<StoreSetupRoute> {
  late final TextEditingController _storeNameController;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(
      text: context.read<StoreSetupBloc>().state.storeName,
    );
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<StoreSetupBloc, StoreSetupState>(
          listenWhen:
              (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
          listener: (context, state) {
            final message = state.errorMessage?.trim();
            if (message == null || message.isEmpty) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            context.read<StoreSetupBloc>().add(const StoreClearMessage());
          },
        ),
        BlocListener<StoreSetupBloc, StoreSetupState>(
          listenWhen: (prev, curr) => curr.isCompleted && !prev.isCompleted,
          listener: (context, state) {
            context.read<StoreSetupBloc>().add(const StoreClearCompleted());
            if (state.skippedStore) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.storeListingRoute,
                (route) => route.isFirst,
              );
              return;
            }
            Navigator.of(
              context,
            ).pushNamed(Routes.addTeamRoute, arguments: state.storeName);
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<StoreSetupBloc, StoreSetupState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppPadding.screen(
                      top: ScreenWrapper.statusBarTop(context),
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppBackButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.textOnPrimary,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: Text(
                            'Create your store',
                            style: AppTextStyles.title(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "Like a channel - a public home for your catalogue with its own link.",
                            style: AppTextStyles.bodySecondary(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        StoreNameField(
                          controller: _storeNameController,
                          onChanged:
                              (value) => context.read<StoreSetupBloc>().add(
                                StoreNameChanged(value),
                              ),
                        ),
                        const SizedBox(height: 14),
                        StoreLinkCard(state: state),
                        const SizedBox(height: 14),
                        Text(
                          'Anyone with this link can view your products - no account needed.',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: Column(
                    children: [
                      PrimaryButton(
                        label: 'Create store',
                        enabled: state.canContinue,
                        isLoading: state.isSubmitting && !state.skippedStore,
                        onPressed:
                            () => context.read<StoreSetupBloc>().add(
                              const StoreCreatePressed(),
                            ),
                      ),
                      // const SizedBox(height: 12),
                      // TextButton(
                      //   onPressed:
                      //       state.isSubmitting
                      //           ? null
                      //           : () => context.read<StoreSetupBloc>().add(
                      //             const StoreSkipPressed(),
                      //           ),
                      //   child: Text(
                      //     'Skip for now',
                      //     style: AppTextStyles.bodySecondary(),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
