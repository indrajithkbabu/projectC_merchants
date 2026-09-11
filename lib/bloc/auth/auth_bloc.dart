import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:project_c/di/service_locator.dart';
import 'package:project_c/helper/app_log.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/country_model.dart';
import 'package:project_c/navigation/routes.dart';
import 'package:project_c/webservice/auth/auth_repository.dart';
import 'package:project_c/webservice/catalog_error_mapper.dart';
import 'package:project_c/webservice/profile/profile_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? authRepository, ProfileRepository? profileRepository})
    : _authRepository = authRepository ?? ServiceLocator.get<AuthRepository>(),
      _profileRepository =
          profileRepository ?? ServiceLocator.get<ProfileRepository>(),
      // App always requests session restore on create; start gated so
      // bootstrap never briefly treats the user as signed-out.
      super(const AuthState(isRestoringSession: true)) {
    on<AuthCountryChanged>(_onCountryChanged);
    on<AuthDigitPressed>(_onDigitPressed);
    on<AuthBackspacePressed>(_onBackspacePressed);
    on<AuthPhoneContinuePressed>(_onPhoneContinue);
    on<AuthOtpContinuePressed>(_onOtpContinue);
    on<AuthResendPressed>(_onResendPressed);
    on<AuthTimerTicked>(_onTimerTicked);
    on<AuthClearMessage>(_onClearMessage);
    on<AuthClearVerified>(_onClearVerified);
    on<AuthClearPhoneSubmitted>(_onClearPhoneSubmitted);
    on<AuthResetPhoneFlow>(_onResetPhoneFlow);
    on<AuthLoggedOut>(_onLoggedOut);
    on<AuthSessionRestoreRequested>(_onSessionRestore);
    on<AuthClearPostAuthNavigation>(_onClearPostAuthNavigation);
  }

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;

  Timer? _resendTimer;
  static const int defaultResendSeconds = 60;

  static const _tag = 'AuthBloc';

  void _onCountryChanged(AuthCountryChanged event, Emitter<AuthState> emit) {
    // Catalog OTP accepts Indian mobiles only.
    if (event.country.isoCode != 'IN') {
      emit(
        state.copyWith(
          errorMessage: 'Only Indian mobile numbers are supported right now.',
        ),
      );
      return;
    }
    final maxLen = event.country.maxNationalLength;
    var phone = state.phoneDigits;
    if (phone.length > maxLen) {
      phone = phone.substring(0, maxLen);
    }
    emit(
      state.copyWith(
        country: event.country,
        phoneDigits: phone,
        clearError: true,
      ),
    );
  }

  void _onDigitPressed(AuthDigitPressed event, Emitter<AuthState> emit) {
    if (event.target == AuthInputTarget.phone) {
      final max = state.country.maxNationalLength;
      if (state.phoneDigits.length >= max) return;
      emit(
        state.copyWith(
          phoneDigits: '${state.phoneDigits}${event.digit}',
          clearError: true,
        ),
      );
      return;
    }

    if (state.otpDigits.length >= 6) return;
    emit(
      state.copyWith(
        otpDigits: '${state.otpDigits}${event.digit}',
        clearError: true,
      ),
    );
  }

  void _onBackspacePressed(
    AuthBackspacePressed event,
    Emitter<AuthState> emit,
  ) {
    if (event.target == AuthInputTarget.phone) {
      if (state.phoneDigits.isEmpty) return;
      emit(
        state.copyWith(
          phoneDigits: state.phoneDigits.substring(
            0,
            state.phoneDigits.length - 1,
          ),
          clearError: true,
        ),
      );
      return;
    }

    if (state.otpDigits.isEmpty) return;
    emit(
      state.copyWith(
        otpDigits: state.otpDigits.substring(0, state.otpDigits.length - 1),
        clearError: true,
      ),
    );
  }

  Future<void> _onPhoneContinue(
    AuthPhoneContinuePressed event,
    Emitter<AuthState> emit,
  ) async {
    if (!state.isPhoneValid) return;
    if (!_isIndianMobile(state.country, state.phoneDigits)) {
      emit(
        state.copyWith(
          errorMessage: 'Enter a valid 10-digit Indian mobile number.',
        ),
      );
      return;
    }
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final challenge = await _authRepository.requestOtp(
        phone: state.e164Phone,
      );
      final resend = challenge.resendAfterSeconds > 0
          ? challenge.resendAfterSeconds
          : defaultResendSeconds;
      _startResendTimer(resend);
      AppLog.d(_tag, 'OTP requested challenge=${challenge.challengeId}');
      emit(
        state.copyWith(
          otpDigits: '',
          isSubmitting: false,
          challengeId: challenge.challengeId,
          resendSeconds: resend,
          phoneSubmitted: true,
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'OTP request failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  /// Production OTP adapter: Indian mobile only (not landline).
  bool _isIndianMobile(CountryModel country, String nationalDigits) {
    if (country.isoCode != 'IN' || country.dialCode != '+91') return false;
    if (nationalDigits.length != 10) return false;
    final first = nationalDigits.codeUnitAt(0);
    // Indian mobiles typically start with 6–9.
    return first >= 0x36 && first <= 0x39;
  }

  Future<void> _onOtpContinue(
    AuthOtpContinuePressed event,
    Emitter<AuthState> emit,
  ) async {
    if (state.otpDigits.length != 6) return;
    final challengeId = state.challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Request a new code and try again.',
        ),
      );
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final result = await _authRepository.verifyOtp(
        phone: state.e164Phone,
        challengeId: challengeId,
        code: state.otpDigits,
      );
      // Prefer fresh /me when available.
      CatalogProfile profile = result.user;
      try {
        profile = await _profileRepository.fetchMe();
      } catch (_) {}

      final nextRoute = _routeForOnboarding(profile.onboarding);
      AppLog.d(_tag, 'OTP verified → $nextRoute');
      emit(
        state.copyWith(
          isSubmitting: false,
          isVerified: true,
          status: AuthStatus.authenticated,
          phoneE164: state.e164Phone,
          profile: profile,
          postAuthRoute: nextRoute,
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'OTP verify failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onResendPressed(
    AuthResendPressed event,
    Emitter<AuthState> emit,
  ) async {
    if (state.resendSeconds > 0 || !state.isPhoneValid) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final challenge = await _authRepository.requestOtp(
        phone: state.e164Phone,
      );
      final resend = challenge.resendAfterSeconds > 0
          ? challenge.resendAfterSeconds
          : defaultResendSeconds;
      _startResendTimer(resend);
      emit(
        state.copyWith(
          otpDigits: '',
          isSubmitting: false,
          challengeId: challenge.challengeId,
          resendSeconds: resend,
          clearError: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'OTP resend failed', e);
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: CatalogErrorMapper.toUserMessage(e),
        ),
      );
    }
  }

  Future<void> _onSessionRestore(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    AppLog.d(
      'TEST_COLD_START',
      '──────── A.ENTRY START ────────\n'
      '  step=restore_begin\n'
      '  expect_A1_A2=unsigned → onboarding/phone\n'
      '  expect_A3=signed → route by onboarding\n'
      '  expect_A4=bad tokens → unsigned',
    );
    emit(state.copyWith(isRestoringSession: true, clearError: true));
    try {
      final cached = await _authRepository.restoreSession();
      if (cached == null) {
        AppLog.d(
          'TEST_COLD_START',
          'RESULT=UNSIGNED (no local tokens)\n'
          '  status=unauthenticated\n'
          '  nextRoute=${Routes.onboardingRoute}\n'
          '  A1=PASS if landed onboarding/phone after kill+launch\n'
          '  A2=PASS if stayed unsigned with no auto-login\n'
          '──────── A.ENTRY END ────────',
        );
        emit(state.copyWith(isRestoringSession: false));
        return;
      }
      final profile = await _profileRepository.fetchMe();
      final nextRoute = _routeForOnboarding(profile.onboarding);
      AppLog.d(
        'TEST_COLD_START',
        'RESULT=SIGNED_IN (session restore OK)\n'
        '  phone=${profile.phone}\n'
        '  onboarding=${profile.onboarding.name}\n'
        '  nextRoute=$nextRoute\n'
        '  A3=PASS if kill+launch lands on this route (not phone)\n'
        '  A3=FAIL if forced to phone despite tokens\n'
        '──────── A.ENTRY END ────────',
      );
      emit(
        state.copyWith(
          isRestoringSession: false,
          status: AuthStatus.authenticated,
          phoneE164: profile.phone,
          profile: profile,
          postAuthRoute: nextRoute,
          isVerified: true,
        ),
      );
    } catch (e) {
      AppLog.e(_tag, 'Session restore failed', e);
      AppLog.d(
        'TEST_COLD_START',
        'RESULT=RESTORE_FAILED → cleared session\n'
        '  error=${CatalogErrorMapper.toUserMessage(e)}\n'
        '  nextRoute=${Routes.onboardingRoute}\n'
        '  A4=PASS if after bad/expired session you land unsigned (onboarding/phone)\n'
        '  A4=FAIL if crash or stuck restoring\n'
        '──────── A.ENTRY END ────────',
      );
      await _authRepository.logout();
      emit(
        state.copyWith(
          isRestoringSession: false,
          status: AuthStatus.unauthenticated,
          clearError: true,
        ),
      );
    }
  }

  void _onTimerTicked(AuthTimerTicked event, Emitter<AuthState> emit) {
    emit(state.copyWith(resendSeconds: event.secondsRemaining));
  }

  void _onClearMessage(AuthClearMessage event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onClearVerified(AuthClearVerified event, Emitter<AuthState> emit) {
    emit(state.copyWith(clearVerified: true));
  }

  void _onClearPhoneSubmitted(
    AuthClearPhoneSubmitted event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(clearPhoneSubmitted: true));
  }

  void _onClearPostAuthNavigation(
    AuthClearPostAuthNavigation event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(clearPostAuthRoute: true, clearVerified: true));
  }

  void _onResetPhoneFlow(AuthResetPhoneFlow event, Emitter<AuthState> emit) {
    _cancelResendTimer();
    emit(
      state.copyWith(
        otpDigits: '',
        resendSeconds: 0,
        clearChallengeId: true,
        clearError: true,
        clearVerified: true,
        clearPhoneSubmitted: true,
      ),
    );
  }

  Future<void> _onLoggedOut(
    AuthLoggedOut event,
    Emitter<AuthState> emit,
  ) async {
    _cancelResendTimer();
    // Clears local session (and best-effort POST /auth/logout when a refresh
    // token is still present). Safe after DELETE /me which may already have
    // cleared tokens via ProfileRepository.deleteAccount.
    AppLog.d(
      'TEST_COLD_START',
      'AuthLoggedOut → clearing AuthBloc\n'
      '  A4 helper: after DELETE /me you should see this then auth_phone_route',
    );
    await _authRepository.logout();
    emit(const AuthState());
  }

  String _routeForOnboarding(CatalogOnboarding onboarding) {
    switch (onboarding) {
      case CatalogOnboarding.nameRequired:
        return Routes.profileSetupRoute;
      case CatalogOnboarding.storeOptional:
        return Routes.storeSetupRoute;
      case CatalogOnboarding.complete:
        return Routes.storeListingRoute;
    }
  }

  void _startResendTimer(int seconds) {
    _cancelResendTimer();
    var remaining = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= 1;
      if (remaining <= 0) {
        timer.cancel();
        add(const AuthTimerTicked(0));
      } else {
        add(AuthTimerTicked(remaining));
      }
    });
  }

  void _cancelResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  @override
  Future<void> close() {
    _cancelResendTimer();
    return super.close();
  }
}
