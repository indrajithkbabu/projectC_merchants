import 'package:flutter/material.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/team/team_widgets/team_member_avatar.dart';

/// Animated strip that appears above the CTA when members are added.
/// Shows avatars + names as dismissible chips.
class AddedMembersBar extends StatelessWidget {
  const AddedMembersBar({
    super.key,
    required this.members,
    required this.onRemove,
  });

  final List<TeamMember> members;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${members.length} ${members.length == 1 ? 'member' : 'members'} added',
                style: AppTextStyles.label(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${members.length}',
                  style: AppTextStyles.caption(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in members) ...[
                  _MemberChip(member: m, onRemove: () => onRemove(m.id)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member, required this.onRemove});

  final TeamMember member;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            TeamMemberAvatar(
              initials: member.initials,
              color: Color(member.avatarColor),
              radius: 24,
            ),
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          member.name.split(' ').first,
          style: AppTextStyles.caption(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
