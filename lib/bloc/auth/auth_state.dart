part of 'auth_bloc.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.phoneE164,
    this.country = CountryModel.defaultCountry,
    this.phoneDigits = '',
    this.otpDigits = '',
    this.challengeId,
    this.resendSeconds = 0,
    this.isSubmitting = false,
    this.isRestoringSession = false,
    this.errorMessage,
    this.isVerified = false,
    this.phoneSubmitted = false,
    this.profile,
    this.postAuthRoute,
  });

  final AuthStatus status;
  final String? phoneE164;
  final CountryModel country;
  final String phoneDigits;
  final String otpDigits;
  final String? challengeId;
  final int resendSeconds;
  final bool isSubmitting;
  final bool isRestoringSession;
  final String? errorMessage;
  final bool isVerified;
  final bool phoneSubmitted;
  final CatalogProfile? profile;
  final String? postAuthRoute;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isPhoneValid =>
      phoneDigits.length >= country.minNationalLength &&
      phoneDigits.length <= country.maxNationalLength;

  bool get canContinuePhone => isPhoneValid && !isSubmitting;

  bool get canContinueOtp => otpDigits.length == 6 && !isSubmitting;

  bool get canResend => resendSeconds <= 0 && !isSubmitting;

  String get e164Phone => '${country.dialCode}$phoneDigits';

  String get displayPhone {
    final raw = phoneDigits;
    if (raw.isEmpty) return '';
    if (raw.length <= 3) return raw;
    if (raw.length <= 6) {
      return '${raw.substring(0, 3)} ${raw.substring(3)}';
    }
    if (raw.length <= 10) {
      return '${raw.substring(0, 3)} ${raw.substring(3, 6)} ${raw.substring(6)}';
    }
    return '${raw.substring(0, 3)} ${raw.substring(3, 6)} ${raw.substring(6, 10)}'
        '${raw.length > 10 ? ' ${raw.substring(10)}' : ''}';
  }

  String get maskedPhoneDisplay => '${country.dialCode} $displayPhone';

  AuthState copyWith({
    AuthStatus? status,
    String? phoneE164,
    CountryModel? country,
    String? phoneDigits,
    String? otpDigits,
    String? challengeId,
    int? resendSeconds,
    bool? isSubmitting,
    bool? isRestoringSession,
    String? errorMessage,
    bool? isVerified,
    bool? phoneSubmitted,
    CatalogProfile? profile,
    String? postAuthRoute,
    bool clearError = false,
    bool clearVerified = false,
    bool clearPhoneSubmitted = false,
    bool clearChallengeId = false,
    bool clearPostAuthRoute = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneE164: phoneE164 ?? this.phoneE164,
      country: country ?? this.country,
      phoneDigits: phoneDigits ?? this.phoneDigits,
      otpDigits: otpDigits ?? this.otpDigits,
      challengeId:
          clearChallengeId ? null : (challengeId ?? this.challengeId),
      resendSeconds: resendSeconds ?? this.resendSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isVerified: clearVerified ? false : (isVerified ?? this.isVerified),
      phoneSubmitted:
          clearPhoneSubmitted ? false : (phoneSubmitted ?? this.phoneSubmitted),
      profile: profile ?? this.profile,
      postAuthRoute:
          clearPostAuthRoute ? null : (postAuthRoute ?? this.postAuthRoute),
    );
  }

  @override
  List<Object?> get props => [
    status,
    phoneE164,
    country,
    phoneDigits,
    otpDigits,
    challengeId,
    resendSeconds,
    isSubmitting,
    isRestoringSession,
    errorMessage,
    isVerified,
    phoneSubmitted,
    profile,
    postAuthRoute,
  ];
}
