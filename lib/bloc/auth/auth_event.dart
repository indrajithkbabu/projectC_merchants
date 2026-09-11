part of 'auth_bloc.dart';

enum AuthInputTarget { phone, otp }

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCountryChanged extends AuthEvent {
  const AuthCountryChanged(this.country);

  final CountryModel country;

  @override
  List<Object?> get props => [country];
}

class AuthDigitPressed extends AuthEvent {
  const AuthDigitPressed(this.digit, {required this.target});

  final String digit;
  final AuthInputTarget target;

  @override
  List<Object?> get props => [digit, target];
}

class AuthBackspacePressed extends AuthEvent {
  const AuthBackspacePressed({required this.target});

  final AuthInputTarget target;

  @override
  List<Object?> get props => [target];
}

class AuthPhoneContinuePressed extends AuthEvent {
  const AuthPhoneContinuePressed();
}

class AuthOtpContinuePressed extends AuthEvent {
  const AuthOtpContinuePressed();
}

class AuthResendPressed extends AuthEvent {
  const AuthResendPressed();
}

class AuthTimerTicked extends AuthEvent {
  const AuthTimerTicked(this.secondsRemaining);

  final int secondsRemaining;

  @override
  List<Object?> get props => [secondsRemaining];
}

class AuthClearMessage extends AuthEvent {
  const AuthClearMessage();
}

class AuthClearVerified extends AuthEvent {
  const AuthClearVerified();
}

class AuthClearPhoneSubmitted extends AuthEvent {
  const AuthClearPhoneSubmitted();
}

class AuthClearPostAuthNavigation extends AuthEvent {
  const AuthClearPostAuthNavigation();
}

class AuthResetPhoneFlow extends AuthEvent {
  const AuthResetPhoneFlow();
}

class AuthLoggedOut extends AuthEvent {
  const AuthLoggedOut();
}

class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}
