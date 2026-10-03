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
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProfileBloc>().state;
    final existing = state.firstName.trim();
    final last = state.lastName.trim();
    final seed =
        existing.isEmpty
            ? ''
            : (last.isEmpty ? existing : '$existing $last');
    _nameController = TextEditingController(text: seed);
    _nameFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    // API still expects firstName; treat the whole field as the display name.
    context.read<ProfileBloc>().add(ProfileFirstNameChanged(value));
    if (context.read<ProfileBloc>().state.lastName.isNotEmpty) {
      context.read<ProfileBloc>().add(const ProfileLastNameChanged(''));
    }
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
            // Store setup is optional — create later from Profile tab.
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.storeListingRoute,
              (route) => false,
            );
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
                            style: AppTextStyles.title(fontSize: 24),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            "Enter your name and a photo so your team knows it's you.",
                            style: AppTextStyles.bodySecondary(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 22),
                        ProfilePhotoPicker(
                          firstName: state.firstName,
                          imagePath: state.imagePath,
                          isLoading: state.isPickingImage,
                          onTap: () => _showImageOptions(state),
                        ),
                        const SizedBox(height: 28),
                        ProfileNameField(
                          label: 'Name',
                          hintText: 'Enter your name',
                          controller: _nameController,
                          focusNode: _nameFocus,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          fontSize: 18,
                          onChanged: _onNameChanged,
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
