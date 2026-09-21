import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_c/bloc/profile/profile_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/profile/profile_widgets/profile_name_field.dart';
import 'package:project_c/presentation/profile/profile_widgets/profile_photo_picker.dart';

class ProfileRoute extends StatefulWidget {
  const ProfileRoute({super.key});

  @override
  State<ProfileRoute> createState() => _ProfileRouteState();
}

class _ProfileRouteState extends State<ProfileRoute> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProfileBloc>().state;
    _firstNameController = TextEditingController(text: state.firstName);
    _lastNameController = TextEditingController(text: state.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _showImageOptions(ProfileState state) async {
    final action = await showModalBottomSheet<_ProfilePhotoAction>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        final hasImage = state.hasImage;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: Text('Use camera', style: AppTextStyles.body()),
                  onTap:
                      () =>
                          Navigator.of(context).pop(_ProfilePhotoAction.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text(
                    'Choose from gallery',
                    style: AppTextStyles.body(),
                  ),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pop(_ProfilePhotoAction.gallery),
                ),
                if (hasImage)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Delete photo',
                      style: AppTextStyles.body(color: AppColors.error),
                    ),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).pop(_ProfilePhotoAction.delete),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    final bloc = context.read<ProfileBloc>();
    switch (action) {
      case _ProfilePhotoAction.camera:
        bloc.add(const ProfilePickImageRequested(ImageSource.camera));
        return;
      case _ProfilePhotoAction.gallery:
        bloc.add(const ProfilePickImageRequested(ImageSource.gallery));
        return;
      case _ProfilePhotoAction.delete:
        bloc.add(const ProfileRemoveImageRequested());
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileBloc, ProfileState>(
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
            context.read<ProfileBloc>().add(const ProfileClearMessage());
          },
        ),
        BlocListener<ProfileBloc, ProfileState>(
          listenWhen: (prev, curr) => curr.isCompleted && !prev.isCompleted,
          listener: (context, state) {
            context.read<ProfileBloc>().add(const ProfileClearCompleted());
            Navigator.of(context).pushNamed(Routes.storeSetupRoute);
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<ProfileBloc, ProfileState>(
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
                          child: Text(
                            'Add your name',
                            style: AppTextStyles.title(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "Enter your name and a photo so your team knows it's you.",
                            style: AppTextStyles.bodySecondary(),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 26),
                        ProfilePhotoPicker(
                          firstName: state.firstName,
                          imagePath: state.imagePath,
                          isLoading: state.isPickingImage,
                          onTap: () => _showImageOptions(state),
                        ),
                        const SizedBox(height: 34),
                        ProfileNameField(
                          label: 'First name',
                          hintText: 'First name',
                          controller: _firstNameController,
                          onChanged:
                              (value) => context.read<ProfileBloc>().add(
                                ProfileFirstNameChanged(value),
                              ),
                        ),
                        const SizedBox(height: 18),
                        ProfileNameField(
                          label: 'Last name (optional)',
                          hintText: 'Last name',
                          controller: _lastNameController,
                          textInputAction: TextInputAction.done,
                          onChanged:
                              (value) => context.read<ProfileBloc>().add(
                                ProfileLastNameChanged(value),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: PrimaryButton(
                    label: 'Continue',
                    enabled: state.canContinue,
                    isLoading: state.isSubmitting,
                    onPressed:
                        () => context.read<ProfileBloc>().add(
                          const ProfileContinuePressed(),
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

enum _ProfilePhotoAction { camera, gallery, delete }
