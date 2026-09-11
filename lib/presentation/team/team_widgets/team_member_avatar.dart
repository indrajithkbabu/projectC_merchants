import 'package:flutter/material.dart';
import 'package:project_c/helper/text_styles.dart';

class TeamMemberAvatar extends StatelessWidget {
  const TeamMemberAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.radius = 22,
  });

  final String initials;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initials,
        style: AppTextStyles.label(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
