import '../domain/entities/app_role.dart';

class PermissionService {
  const PermissionService();

  bool hasAnyRole(List<AppRole> currentRoles, Set<AppRole> expectedRoles) {
    final current = currentRoles.toSet();
    return current.intersection(expectedRoles).isNotEmpty;
  }

  bool canAccessPdv(List<AppRole> roles) {
    return hasAnyRole(roles, {
      AppRole.admin,
      AppRole.manager,
      AppRole.seller,
      AppRole.cashier,
    });
  }

  bool canAccessErp(List<AppRole> roles) {
    return hasAnyRole(roles, {AppRole.admin, AppRole.manager});
  }

  bool canAccessCrm(List<AppRole> roles) {
    return hasAnyRole(roles, {AppRole.admin, AppRole.manager, AppRole.crmUser});
  }

  bool canAccessSettings(List<AppRole> roles) {
    return roles.contains(AppRole.admin);
  }
}
