import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/store_setup/store_setup_bloc.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/profile_switching_log.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/main/app.dart' show scaffoldMessengerKey;
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/main_shell/shell_nav.dart';
import 'package:project_c/presentation/store_setup/store_setup_widgets/store_link_card.dart';
import 'package:project_c/presentation/store_setup/store_setup_widgets/store_setup_identity_card.dart';
import 'package:project_c/presentation/store_setup/store_setup_widgets/store_setup_photos_preview_sheet.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';
import 'package:project_c/webservice/store/store_request.dart';

class StoreSetupRoute extends StatefulWidget {
  const StoreSetupRoute({super.key});

  @override
  State<StoreSetupRoute> createState() => _StoreSetupRouteState();
}

class _StoreSetupRouteState extends State<StoreSetupRoute> {
  late final TextEditingController _storeNameController;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController(
      text: context.read<StoreSetupBloc>().state.storeName,
    );
    _nameFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onPhotoAction(StoreSetupState state) {
    if (state.isPickingImages || state.isSubmitting) return;
    if (state.imagePaths.isEmpty) {
      context.read<StoreSetupBloc>().add(const StoreImagesPickRequested());
      return;
    }
    showStoreSetupPhotosPreviewSheet(context);
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
          listener: (context, state) async {
            context.read<StoreSetupBloc>().add(const StoreClearCompleted());
            if (state.skippedStore) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.storeListingRoute,
                (route) => route.isFirst,
              );
              return;
            }

            final storeId = state.createdStoreId?.trim() ?? '';
            final storeName = state.storeName.trim();
            final toast =
                storeName.isEmpty ? 'Store created' : '$storeName created';

            ProfileSwitchingLog.d(
              'PS-30/31/32',
              'create completed storeId=$storeId name=$storeName '
              '→ PATCH active-profile store:$storeId',
            );

            // Create does not auto-select — FE must PATCH before remounting shell.
            if (storeId.isNotEmpty) {
              try {
                await ServiceLocator.get<ProfileRepository>()
                    .selectActiveProfile('store:$storeId');
                ProfileSwitchingLog.d(
                  'PS-30/34',
                  'post-create select ok store:$storeId',
                );
              } catch (e) {
                ProfileSwitchingLog.e(
                  'PS-32',
                  'post-create select failed storeId=$storeId '
                  '(store exists — do not create again)',
                  e,
                );
                // Shell refresh will reconcile; still land on listing.
              }
            }

            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.storeListingRoute,
              (route) => false,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ShellNav.request(ShellNavTab.profile);
              scaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text(toast)),
              );
            });
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.scaffold,
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
                        Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: AppBackButton(
                                color: AppColors.textPrimary,
                                onPressed:
                                    () => Navigator.of(context).maybePop(),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Create your store',
                                style: AppTextStyles.headline(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Like a channel — a public home for your catalogue with its own link.',
                          style: AppTextStyles.bodySecondary(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can upload up to ${StoreRequest.maxStoreImages} store photos.',
                          style: AppTextStyles.caption(),
                        ),
                        const SizedBox(height: 16),
                        StoreSetupIdentityCard(
                          controller: _storeNameController,
                          focusNode: _nameFocus,
                          imagePaths: state.imagePaths,
                          isPickingImages: state.isPickingImages,
                          onNameChanged:
                              (value) => context.read<StoreSetupBloc>().add(
                                StoreNameChanged(value),
                              ),
                          onPickImages: () => _onPhotoAction(state),
                          onPreviewImages: () => _onPhotoAction(state),
                        ),
                        const SizedBox(height: 14),
                        StoreLinkCard(state: state),
                        const SizedBox(height: 10),
                        Text(
                          'Anyone with this link can view your products — no account needed.',
                          style: AppTextStyles.caption(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: PrimaryButton(
                    label: 'Create store',
                    enabled: state.canContinue,
                    isLoading: state.isSubmitting && !state.skippedStore,
                    onPressed:
                        () => context.read<StoreSetupBloc>().add(
                          const StoreCreatePressed(),
                        ),
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
