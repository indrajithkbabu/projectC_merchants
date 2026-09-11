import 'package:equatable/equatable.dart';
import 'package:project_c/models/catalog/catalog_profile.dart';
import 'package:project_c/models/catalog/catalog_tokens.dart';

class OtpChallenge extends Equatable {
  const OtpChallenge({
    required this.challengeId,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  final String challengeId;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) {
    return OtpChallenge(
      challengeId: json['challengeId'] as String? ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 300,
      resendAfterSeconds: (json['resendAfterSeconds'] as num?)?.toInt() ?? 60,
    );
  }

  @override
  List<Object?> get props => [
    challengeId,
    expiresInSeconds,
    resendAfterSeconds,
  ];
}

class AuthSessionResult extends Equatable {
  const AuthSessionResult({required this.user, required this.tokens});

  final CatalogProfile user;
  final CatalogTokens tokens;

  factory AuthSessionResult.fromJson(Map<String, dynamic> json) {
    return AuthSessionResult(
      user: CatalogProfile.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
      tokens: CatalogTokens.fromJson(
        json['tokens'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  @override
  List<Object?> get props => [user, tokens];
}
