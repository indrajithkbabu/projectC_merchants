import 'package:equatable/equatable.dart';

class CatalogTokens extends Equatable {
  const CatalogTokens({
    required this.accessToken,
    required this.accessExpiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String accessExpiresAt;
  final String refreshToken;
  final String refreshExpiresAt;

  factory CatalogTokens.fromJson(Map<String, dynamic> json) {
    return CatalogTokens(
      accessToken: json['accessToken'] as String? ?? '',
      accessExpiresAt: json['accessExpiresAt'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      refreshExpiresAt: json['refreshExpiresAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'accessExpiresAt': accessExpiresAt,
    'refreshToken': refreshToken,
    'refreshExpiresAt': refreshExpiresAt,
  };

  @override
  List<Object?> get props => [
    accessToken,
    accessExpiresAt,
    refreshToken,
    refreshExpiresAt,
  ];
}
