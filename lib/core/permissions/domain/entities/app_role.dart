enum AppRole {
  admin('admin'),
  manager('manager'),
  seller('seller'),
  cashier('cashier'),
  crmUser('crm_user');

  const AppRole(this.wireValue);

  final String wireValue;

  static AppRole fromWireValue(String value) {
    return AppRole.values.firstWhere(
      (role) => role.wireValue == value,
      orElse: () => AppRole.seller,
    );
  }

  String get label => switch (this) {
    AppRole.admin => 'Admin',
    AppRole.manager => 'Manager',
    AppRole.seller => 'Seller',
    AppRole.cashier => 'Cashier',
    AppRole.crmUser => 'CRM User',
  };
}
