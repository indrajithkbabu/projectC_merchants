part of 'onboarding_bloc.dart';

class OnboardingState extends Equatable {
  const OnboardingState({this.navigateToAuth = false});

  final bool navigateToAuth;

  OnboardingState copyWith({bool? navigateToAuth}) {
    return OnboardingState(
      navigateToAuth: navigateToAuth ?? this.navigateToAuth,
    );
  }

  @override
  List<Object?> get props => [navigateToAuth];
}
