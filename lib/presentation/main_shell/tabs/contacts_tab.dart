import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_c/bloc/contacts/contacts_bloc.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/floating_bottom_nav_bar.dart';
import 'package:project_c/helper/widgets/screen_wrapper.dart';
import 'package:project_c/models/catalog/store_member_models.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/presentation/onboarding/onboarding_widgets/jewel_flow_logo.dart';

class ContactsTab extends StatelessWidget {
  const ContactsTab({super.key});

  String _initials(StoreMember member) {
    final name = member.displayName.trim();
    final first = member.firstName?.trim() ?? '';
    final last = member.lastName?.trim() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length.clamp(0, 2)).toUpperCase();
    }
    // Prefer contact / display name initials over phone digits.
    if (name.isNotEmpty &&
        name != member.phone.trim() &&
        !name.startsWith('+') &&
        !RegExp(r'^\d+$').hasMatch(name)) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2 &&
          parts.first.isNotEmpty &&
          parts.last.isNotEmpty) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
    }
    final phone = member.phone;
    if (phone.length >= 2) return phone.substring(phone.length - 2);
    return '?';
  }

  Future<void> _pullToRefresh(BuildContext context) async {
    final bloc = context.read<ContactsBloc>();
    bloc.add(const ContactsRefreshed());
    await bloc.stream.firstWhere((s) => !s.isRefreshing);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = FloatingBottomNavBar.reservedHeight(context) + 8;
    return BlocListener<ContactsBloc, ContactsState>(
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
        context.read<ContactsBloc>().add(const ContactsClearMessage());
      },
      child: BlocBuilder<ContactsBloc, ContactsState>(
        builder: (context, state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: AppPadding.screen(
                  top: ScreenWrapper.statusBarTop(context) + 8,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contacts',
                      style: AppTextStyles.headline(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.hasOwnStore
                          ? (state.storeName == null
                              ? 'People in your store'
                              : 'People in ${state.storeName}')
                          : 'Team members from your store',
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => _pullToRefresh(context),
                  child:
                      !state.hasOwnStore && !state.isRefreshing
                          ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppPadding.screen(
                              top: 48,
                              bottom: bottomPad,
                            ),
                            children: [
                              const Center(child: JewelFlowLogo(size: 56)),
                              const SizedBox(height: 20),
                              Text(
                                'No store yet',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.title(fontSize: 20),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create a store to invite contacts and manage your team.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySecondary(
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: TextButton(
                                  onPressed:
                                      () => Navigator.of(
                                        context,
                                      ).pushNamed(Routes.storeSetupRoute),
                                  child: const Text('Create store'),
                                ),
                              ),
                            ],
                          )
                          : state.members.isEmpty
                          ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppPadding.screen(
                              top: 48,
                              bottom: bottomPad,
                            ),
                            children: [
                              Text(
                                'No contacts yet',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySecondary(),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Invite people from your store setup or team screen.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption(),
                              ),
                            ],
                          )
                          : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppPadding.screen(
                              top: 8,
                              bottom: bottomPad,
                            ),
                            itemCount: state.members.length,
                            separatorBuilder:
                                (_, __) => const Divider(
                                  height: 1,
                                  indent: 68,
                                  color: AppColors.border,
                                ),
                            itemBuilder: (context, index) {
                              final member = state.members[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  child: Text(
                                    _initials(member),
                                    style: AppTextStyles.label(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  member.displayName,
                                  style: AppTextStyles.body(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  member.phone,
                                  style: AppTextStyles.caption(),
                                ),
                                trailing:
                                    member.signedUp
                                        ? null
                                        : Text(
                                          'Invited',
                                          style: AppTextStyles.caption(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                              );
                            },
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
