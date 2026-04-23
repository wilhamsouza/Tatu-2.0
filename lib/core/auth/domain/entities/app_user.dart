import '../../../permissions/domain/entities/app_role.dart';

class AppUser {
  const AppUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.roles,
    required this.companyId,
  });

  final String userId;
  final String name;
  final String email;
  final List<AppRole> roles;
  final String companyId;
}
