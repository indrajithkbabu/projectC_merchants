import 'package:flutter/material.dart';
import 'package:project_c/bloc/team/team_bloc.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/presentation/team/team_widgets/team_member_avatar.dart';

class TeamMemberTile extends StatelessWidget {
  const TeamMemberTile({
    super.key,
    required this.member,
    required this.isAdded,
    required this.onToggle,
  });

  final TeamMember member;
  final bool isAdded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: TeamMemberAvatar(
        initials: member.initials,
        color: Color(member.avatarColor),
      ),
      title: Text(
        member.name,
        style: AppTextStyles.body(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        member.phone.isNotEmpty ? member.phone : member.handle,
        style: AppTextStyles.caption(),
      ),
      trailing: _AddedButton(isAdded: isAdded, onTap: onToggle),
    );
  }
}

class _AddedButton extends StatelessWidget {
  const _AddedButton({required this.isAdded, required this.onTap});

  final bool isAdded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color:
              isAdded
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          border: Border.all(
            color: isAdded ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdded) ...[
              const Icon(
                Icons.check_rounded,
                size: 13,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              isAdded ? 'Added' : 'Add',
              style: AppTextStyles.caption(
                fontWeight: FontWeight.w600,
                color: isAdded ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
