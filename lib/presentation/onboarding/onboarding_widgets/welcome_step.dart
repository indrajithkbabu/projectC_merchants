import 'package:flutter/material.dart';
import 'package:project_c/helper/app_padding.dart';
import 'package:project_c/helper/text_styles.dart';
import 'package:project_c/helper/widgets/primary_button.dart';
import 'package:project_c/presentation/onboarding/onboarding_widgets/jewel_flow_logo.dart';

class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _ctaSlide;
  late final Animation<double> _ctaOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4, curve: Curves.easeOut),
    );
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
      ),
    );
    _ctaOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.screenHorizontal,
      child: Column(
        children: [
          const Spacer(flex: 3),
          FadeTransition(
            opacity: _logoOpacity,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.86, end: 1).animate(_logoScale),
              child: Column(
                children: [
                  const JewelFlowLogo(size: 92),
                  const SizedBox(height: 28),
                  Text(
                    'Jewel Flow',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'The shared catalogue for jewellers.\nBuild a store, upload once, share everywhere.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary(
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 4),
          FadeTransition(
            opacity: _ctaOpacity,
            child: SlideTransition(
              position: _ctaSlide,
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Continue',
                    height: 54,
                    onPressed: widget.onContinue,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
