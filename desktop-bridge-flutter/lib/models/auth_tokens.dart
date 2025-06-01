import 'package:json_annotation/json_annotation.dart';

part 'auth_tokens.g.dart';

@JsonSerializable()
class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String tokenType;
  final DateTime expiresAt;

  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    required this.tokenType,
    required this.expiresAt,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);

  Map<String, dynamic> toJson() => _$AuthTokensToJson(this);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  bool get isExpiringSoon => 
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    String? idToken,
    String? tokenType,
    DateTime? expiresAt,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      idToken: idToken ?? this.idToken,
      tokenType: tokenType ?? this.tokenType,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  String toString() {
    return 'AuthTokens(tokenType: $tokenType, expiresAt: $expiresAt, hasRefreshToken: ${refreshToken != null})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthTokens &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.idToken == idToken &&
        other.tokenType == tokenType &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return accessToken.hashCode ^
        refreshToken.hashCode ^
        idToken.hashCode ^
        tokenType.hashCode ^
        expiresAt.hashCode;
  }
}
