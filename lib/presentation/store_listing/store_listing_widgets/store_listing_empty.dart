import 'package:flutter/material.dart';
import 'package:project_c/helper/colors.dart';
import 'package:project_c/helper/text_styles.dart';

/// Soft looping empty illustration for the Stores home list.
class StoreListingEmpty extends StatefulWidget {
  const StoreListingEmpty({super.key});

  @override
  State<StoreListingEmpty> createState() => _StoreListingEmptyState();
}

class _StoreListingEmptyState extends State<StoreListingEmpty>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pulse = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _float.value),
                child: Transform.scale(
                  scale: _pulse.value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceSecondary,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'No stores yet',
            style: AppTextStyles.body(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          // const SizedBox(height: 8),
          // Text(
          //   'Follow stores or invite friends — their catalogues will show up here.',
          //   style: AppTextStyles.bodySecondary(fontSize: 14, height: 1.4),
          //   textAlign: TextAlign.center,
          // ),
        ],
      ),
    );
  }
}
