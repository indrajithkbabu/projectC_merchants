part of 'onboarding_bloc.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

class OnboardingContinuePressed extends OnboardingEvent {
  const OnboardingContinuePressed();
}

class OnboardingClearNavigateToAuth extends OnboardingEvent {
  const OnboardingClearNavigateToAuth();
}
