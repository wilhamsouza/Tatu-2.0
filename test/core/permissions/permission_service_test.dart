import 'package:flutter_test/flutter_test.dart';
import 'package:tatuzin/core/permissions/application/permission_service.dart';
import 'package:tatuzin/core/permissions/domain/entities/app_role.dart';

void main() {
  group('PermissionService', () {
    const service = PermissionService();

    test('allows ERP only for admin and manager', () {
      expect(service.canAccessErp(const [AppRole.admin]), isTrue);
      expect(service.canAccessErp(const [AppRole.manager]), isTrue);
      expect(service.canAccessErp(const [AppRole.seller]), isFalse);
    });

    test('allows PDV for cashier and seller', () {
      expect(service.canAccessPdv(const [AppRole.cashier]), isTrue);
      expect(service.canAccessPdv(const [AppRole.seller]), isTrue);
    });
  });
}
