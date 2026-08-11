import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState()) {
    on<OnboardingContinuePressed>(_onContinuePressed);
    on<OnboardingClearNavigateToAuth>(_onClearNavigate);
  }

  void _onContinuePressed(
    OnboardingContinuePressed event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(navigateToAuth: true));
  }

  void _onClearNavigate(
    OnboardingClearNavigateToAuth event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(navigateToAuth: false));
  }
}
