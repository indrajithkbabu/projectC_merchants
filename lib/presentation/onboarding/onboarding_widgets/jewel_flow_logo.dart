import 'package:flutter/material.dart';
import 'package:project_c/helper/assets.dart';

class JewelFlowLogo extends StatelessWidget {
  const JewelFlowLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        AppAssets.appLogo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
