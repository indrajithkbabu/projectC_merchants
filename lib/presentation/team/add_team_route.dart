import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/app_back_button.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/team/team_widgets/added_members_bar.dart';
import 'package:project_c/presentation/team/team_widgets/team_member_tile.dart';
import 'package:project_c/presentation/team/team_widgets/team_search_field.dart';

class AddTeamRoute extends StatefulWidget {
  /// [storeName] is shown in the subtitle for context.
  ///
  /// When [returnToProfile] is true (opened from store profile), Continue/Skip
  /// pops back to the profile instead of clearing to the store listing.
  const AddTeamRoute({
    super.key,
    required this.storeName,
    this.returnToProfile = false,
  });

  final String storeName;
  final bool returnToProfile;

  @override
  State<AddTeamRoute> createState() => _AddTeamRouteState();
}

class _AddTeamRouteState extends State<AddTeamRoute> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TeamBloc, TeamState>(
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
            context.read<TeamBloc>().add(const TeamClearMessage());
          },
        ),
        BlocListener<TeamBloc, TeamState>(
          listenWhen: (prev, curr) => curr.isCompleted && !prev.isCompleted,
          listener: (context, state) {
            context.read<TeamBloc>().add(const TeamClearCompleted());
            if (widget.returnToProfile) {
              Navigator.of(context).pop(true);
              return;
            }
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.storeListingRoute,
              (route) => false,
              arguments: <String, Object?>{
                'storeName': widget.storeName,
                'members': state.addedMembers,
              },
            );
          },
        ),
      ],
      child: ScreenWrapper(
        backgroundColor: AppColors.background,
        statusBarIconBrightness: Brightness.dark,
        child: BlocBuilder<TeamBloc, TeamState>(
          builder: (context, state) {
            return Column(
              children: [
                _TeamAppBar(storeName: widget.storeName),
                Padding(
                  padding: AppPadding.screen(top: 10, bottom: 10),
                  child: TeamSearchField(
                    controller: _searchController,
                    onChanged:
                        (q) =>
                            context.read<TeamBloc>().add(TeamSearchChanged(q)),
                  ),
                ),
                Expanded(child: _TeamBody(state: state)),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: AddedMembersBar(
                    members: state.addedMembers,
                    onRemove:
                        (id) =>
                            context.read<TeamBloc>().add(TeamMemberToggled(id)),
                  ),
                ),
                Padding(
                  padding: AppPadding.screen(top: 8, bottom: 24),
                  child: PrimaryButton(
                    label:
                        state.addedCount == 0
                            ? 'Skip for now'
                            : (widget.returnToProfile
                                ? 'Done'
                                : 'Continue to store'),
                    isLoading: state.isSubmitting,
                    onPressed:
                        () => context.read<TeamBloc>().add(
                          const TeamContinuePressed(),
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

class _TeamBody extends StatelessWidget {
  const _TeamBody({required this.state});

  final TeamState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.permissionDenied) {
      return Padding(
        padding: AppPadding.screen(top: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Contacts access is needed to add teammates from your phone book.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed:
                  () => context.read<TeamBloc>().add(
                    const TeamContactsLoadRequested(),
                  ),
              child: Text(
                'Allow contacts',
                style: AppTextStyles.body(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Or tap Skip for now to continue without adding anyone.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(),
            ),
          ],
        ),
      );
    }

    if (state.searchResults.isEmpty) {
      return Center(
        child: Text(
          state.query.trim().isEmpty
              ? 'No contacts with phone numbers found'
              : 'No people found',
          style: AppTextStyles.bodySecondary(),
        ),
      );
    }

    return ListView.separated(
      padding: AppPadding.screen(top: 4, bottom: 16),
      itemCount: state.searchResults.length,
      separatorBuilder:
          (_, __) => const Divider(
            height: 1,
            indent: 56,
            color: AppColors.border,
          ),
      itemBuilder: (context, index) {
        final member = state.searchResults[index];
        final isAdded = state.addedIds.contains(member.id);
        return TeamMemberTile(
          member: member,
          isAdded: isAdded,
          onToggle:
              () => context.read<TeamBloc>().add(
                TeamMemberToggled(member.id),
              ),
        );
      },
    );
  }
}

class _TeamAppBar extends StatelessWidget {
  const _TeamAppBar({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: ScreenWrapper.statusBarTop(context) + 8,
        left: AppPadding.horizontal,
        right: AppPadding.horizontal,
        bottom: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBackButton(onPressed: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 8),
          Text('Add your team', style: AppTextStyles.title()),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodySecondary(fontSize: 14),
              children: [
                const TextSpan(
                  text:
                      'Choose contacts to add to ',
                ),
                TextSpan(
                  text: storeName.isEmpty ? 'your store' : storeName,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text:
                      '. They can upload and manage products. You can skip and do this later.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}
