class RemoteAuthSessionDto {
  const RemoteAuthSessionDto({
    required this.userId,
    required this.name,
    required this.email,
    required this.companyId,
    required this.companyName,
    required this.roles,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  final String userId;
  final String name;
  final String email;
  final String companyId;
  final String companyName;
  final List<String> roles;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;

  factory RemoteAuthSessionDto.fromJson(Map<String, dynamic> json) {
    final user =
        json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final tokens =
        json['tokens'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return RemoteAuthSessionDto(
      userId: user['userId'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
      companyId: user['companyId'] as String,
      companyName: user['companyName'] as String,
      roles: (user['roles'] as List<dynamic>).cast<String>(),
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      accessTokenExpiresAt: DateTime.parse(tokens['expiresAt'] as String),
    );
  }
}
