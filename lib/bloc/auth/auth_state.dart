part of 'auth_bloc.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.phoneE164,
    this.country = CountryModel.defaultCountry,
    this.phoneDigits = '',
    this.otpDigits = '',
    this.resendSeconds = 0,
    this.isSubmitting = false,
    this.errorMessage,
    this.isVerified = false,
    this.phoneSubmitted = false,
  });

  final AuthStatus status;
  final String? phoneE164;
  final CountryModel country;
  final String phoneDigits;
  final String otpDigits;
  final int resendSeconds;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isVerified;
  final bool phoneSubmitted;

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
    int? resendSeconds,
    bool? isSubmitting,
    String? errorMessage,
    bool? isVerified,
    bool? phoneSubmitted,
    bool clearError = false,
    bool clearVerified = false,
    bool clearPhoneSubmitted = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneE164: phoneE164 ?? this.phoneE164,
      country: country ?? this.country,
      phoneDigits: phoneDigits ?? this.phoneDigits,
      otpDigits: otpDigits ?? this.otpDigits,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isVerified: clearVerified ? false : (isVerified ?? this.isVerified),
      phoneSubmitted: clearPhoneSubmitted
          ? false
          : (phoneSubmitted ?? this.phoneSubmitted),
    );
  }

  @override
  List<Object?> get props => [
        status,
        phoneE164,
        country,
        phoneDigits,
        otpDigits,
        resendSeconds,
        isSubmitting,
        errorMessage,
        isVerified,
        phoneSubmitted,
      ];
}
