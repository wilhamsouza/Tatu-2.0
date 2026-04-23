import 'package:go_router/go_router.dart';

import '../core/auth/presentation/pages/login_page.dart';
import '../modules/crm/customers/presentation/pages/crm_customers_page.dart';
import '../modules/dashboard/presentation/pages/dashboard_page.dart';
import '../modules/erp/products/presentation/pages/erp_products_page.dart';
import '../modules/pdv/catalog/presentation/pages/pdv_catalog_page.dart';
import '../modules/settings/presentation/pages/settings_page.dart';
import '../modules/dashboard/presentation/pages/root_redirect_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'root',
      builder: (context, state) => const RootRedirectPage(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      name: 'dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/pdv',
      name: 'pdv',
      builder: (context, state) => const PdvCatalogPage(),
    ),
    GoRoute(
      path: '/erp',
      name: 'erp',
      builder: (context, state) => const ErpProductsPage(),
    ),
    GoRoute(
      path: '/crm',
      name: 'crm',
      builder: (context, state) => const CrmCustomersPage(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
