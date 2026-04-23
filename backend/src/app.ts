import "dotenv/config";

import cors from "cors";
import express, { type Express } from "express";
import helmet from "helmet";

import { JwtService } from "./core/auth/jwt.service.js";
import { getPrismaClient } from "./core/database/prisma.client.js";
import { resolvePersistenceMode } from "./core/database/persistence-mode.js";
import { logger } from "./core/logging/logger.js";
import {
  isOriginAllowed,
  resolveAllowedCorsOrigins,
} from "./core/validation/runtime-env.js";
import { createAuthRouter } from "./modules/auth/auth.routes.js";
import type { AuthServiceContract } from "./modules/auth/auth.contract.js";
import { AuthService } from "./modules/auth/auth.service.js";
import { PrismaAuthService } from "./modules/auth/prisma-auth.service.js";
import { createCashRouter } from "./modules/cash/cash.routes.js";
import { createCatalogRouter } from "./modules/catalog/catalog.routes.js";
import type { CatalogServiceContract } from "./modules/catalog/catalog.contract.js";
import { CatalogService } from "./modules/catalog/catalog.service.js";
import { PrismaCatalogService } from "./modules/catalog/prisma-catalog.service.js";
import type { CompanyServiceContract } from "./modules/companies/company.contract.js";
import { CompanyService } from "./modules/companies/company.service.js";
import { createCompaniesRouter } from "./modules/companies/companies.routes.js";
import { PrismaCompanyService } from "./modules/companies/prisma-company.service.js";
import {
  createCrmAdminRouter,
  createCrmRouter,
} from "./modules/crm/crm.routes.js";
import type { CrmServiceContract } from "./modules/crm/crm.contract.js";
import { CrmService } from "./modules/crm/crm.service.js";
import { PrismaCrmService } from "./modules/crm/prisma-crm.service.js";
import { createDevicesRouter } from "./modules/devices/devices.routes.js";
import { DeviceService } from "./modules/devices/device.service.js";
import type { DeviceServiceContract } from "./modules/devices/device.contract.js";
import { PrismaDeviceService } from "./modules/devices/prisma-device.service.js";
import type { InventoryServiceContract } from "./modules/inventory/inventory.contract.js";
import { createInventoryRouter } from "./modules/inventory/inventory.routes.js";
import { InventoryService } from "./modules/inventory/inventory.service.js";
import { PrismaInventoryService } from "./modules/inventory/prisma-inventory.service.js";
import type { PurchasesServiceContract } from "./modules/purchases/purchases.contract.js";
import { PrismaPurchasesService } from "./modules/purchases/prisma-purchases.service.js";
import { createPurchasesRouter } from "./modules/purchases/purchases.routes.js";
import { PurchasesService } from "./modules/purchases/purchases.service.js";
import type { ReportsServiceContract } from "./modules/reports/reports.contract.js";
import { createReportsRouter } from "./modules/reports/reports.routes.js";
import { ReportsService } from "./modules/reports/reports.service.js";
import { createSuppliersRouter } from "./modules/purchases/suppliers.routes.js";
import { createSalesRouter } from "./modules/sales/sales.routes.js";
import type { ReceivableServiceContract } from "./modules/sales/receivable.contract.js";
import { PrismaReceivableService } from "./modules/sales/prisma-receivable.service.js";
import { ReceivableService } from "./modules/sales/receivable.service.js";
import { createReceivablesRouter } from "./modules/sales/receivables.routes.js";
import { PrismaSalesService } from "./modules/sales/prisma-sales.service.js";
import type { SalesServiceContract } from "./modules/sales/sales.contract.js";
import { SalesService } from "./modules/sales/sales.service.js";
import { SyncCashService } from "./modules/sync/sync-cash.service.js";
import type { SyncCashServiceContract } from "./modules/sync/sync-cash.contract.js";
import { PrismaSyncCashService } from "./modules/sync/prisma-sync-cash.service.js";
import { PrismaSyncCustomerService } from "./modules/sync/prisma-sync-customer.service.js";
import { PrismaSyncObservabilityService } from "./modules/sync/prisma-sync-observability.service.js";
import type { SyncCustomerServiceContract } from "./modules/sync/sync-customer.contract.js";
import { SyncCustomerService } from "./modules/sync/sync-customer.service.js";
import { createSyncRouter } from "./modules/sync/sync.routes.js";
import { SyncService } from "./modules/sync/sync.service.js";
import { SyncUpdatesService } from "./modules/sync/sync-updates.service.js";
import type { UsersServiceContract } from "./modules/users/users.contract.js";
import { PrismaUsersService } from "./modules/users/prisma-users.service.js";
import { createUsersRouter } from "./modules/users/users.routes.js";
import { UsersService } from "./modules/users/users.service.js";

export interface ApplicationServices {
  jwtService: JwtService;
  authService: AuthService;
  authRouteService: AuthServiceContract;
  deviceService: DeviceService;
  deviceRouteService: DeviceServiceContract;
  companyService: CompanyService;
  companyRouteService: CompanyServiceContract;
  usersService: UsersService;
  usersRouteService: UsersServiceContract;
  catalogService: CatalogService;
  catalogRouteService: CatalogServiceContract;
  inventoryService: InventoryService;
  inventoryRouteService: InventoryServiceContract;
  purchasesService: PurchasesService;
  purchasesRouteService: PurchasesServiceContract;
  reportsService: ReportsService;
  reportsRouteService: ReportsServiceContract;
  receivableService: ReceivableService;
  receivableRouteService: ReceivableServiceContract;
  salesService: SalesService;
  salesRouteService: SalesServiceContract;
  crmService: CrmService;
  crmRouteService: CrmServiceContract;
  syncCustomerService: SyncCustomerService;
  syncCustomerRouteService: SyncCustomerServiceContract;
  syncCashService: SyncCashService;
  syncCashRouteService: SyncCashServiceContract;
  syncUpdatesService: SyncUpdatesService;
  syncService: SyncService;
}

export function createApplicationServices(): ApplicationServices {
  const jwtService = new JwtService(
    process.env.JWT_ACCESS_SECRET ?? "tatuzin-access-secret",
    process.env.JWT_REFRESH_SECRET ?? "tatuzin-refresh-secret",
  );
  const authService = new AuthService(jwtService);
  const deviceService = new DeviceService();
  const companyService = new CompanyService();
  const usersService = new UsersService();
  const catalogService = new CatalogService();
  const prisma =
    resolvePersistenceMode() === "prisma" ? getPrismaClient() : undefined;
  const authRouteService =
    prisma != null ? new PrismaAuthService(prisma, jwtService) : authService;
  const deviceRouteService =
    prisma != null ? new PrismaDeviceService(prisma) : deviceService;
  const companyRouteService =
    prisma != null ? new PrismaCompanyService(prisma) : companyService;
  const usersRouteService =
    prisma != null ? new PrismaUsersService(prisma) : usersService;
  const catalogRouteService =
    prisma != null
      ? new PrismaCatalogService(prisma)
      : catalogService;
  const inventoryService = new InventoryService();
  const inventoryRouteService =
    prisma != null ? new PrismaInventoryService(prisma) : inventoryService;
  const purchasesService = new PurchasesService(
    catalogService,
    inventoryService,
  );
  const purchasesRouteService =
    prisma != null
      ? new PrismaPurchasesService(prisma, catalogRouteService)
      : purchasesService;
  const receivableService = new ReceivableService();
  const salesService = new SalesService(receivableService);
  const receivableRouteService =
    prisma != null ? new PrismaReceivableService(prisma) : receivableService;
  const salesRouteService =
    prisma != null
      ? new PrismaSalesService(prisma, receivableRouteService)
      : salesService;
  const crmService = new CrmService(salesService, receivableService);
  const reportsService = new ReportsService(
    catalogService,
    salesService,
    receivableService,
  );
  const reportsRouteService =
    prisma != null
      ? new ReportsService(
          catalogRouteService,
          salesRouteService,
          receivableRouteService,
        )
      : reportsService;
  const crmRouteService =
    prisma != null ? new PrismaCrmService(prisma) : crmService;
  const syncCustomerService = new SyncCustomerService(crmService);
  const syncCustomerRouteService =
    prisma != null
      ? new PrismaSyncCustomerService(prisma)
      : syncCustomerService;
  const syncCashService = new SyncCashService();
  const syncCashRouteService =
    prisma != null ? new PrismaSyncCashService(prisma) : syncCashService;
  const syncUpdatesService = new SyncUpdatesService();
  const syncService = new SyncService(
    salesRouteService,
    receivableRouteService,
    syncCustomerRouteService,
    syncCashRouteService,
    syncUpdatesService,
    prisma != null ? new PrismaSyncObservabilityService(prisma) : undefined,
  );

  return {
    jwtService,
    authService,
    authRouteService,
    deviceService,
    deviceRouteService,
    companyService,
    companyRouteService,
    usersService,
    usersRouteService,
    catalogService,
    catalogRouteService,
    inventoryService,
    inventoryRouteService,
    purchasesService,
    purchasesRouteService,
    reportsService,
    reportsRouteService,
    receivableService,
    receivableRouteService,
    salesService,
    salesRouteService,
    crmService,
    crmRouteService,
    syncCustomerService,
    syncCustomerRouteService,
    syncCashService,
    syncCashRouteService,
    syncUpdatesService,
    syncService,
  };
}

export function createApp(services = createApplicationServices()): Express {
  const app = express();
  const allowedCorsOrigins = resolveAllowedCorsOrigins();

  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        callback(null, isOriginAllowed(origin, allowedCorsOrigins));
      },
    }),
  );
  app.use(express.json());
  app.use((request, response, next) => {
    const startedAt = Date.now();
    response.on("finish", () => {
      logger.info(
        {
          method: request.method,
          path: request.path,
          statusCode: response.statusCode,
          responseTimeMs: Date.now() - startedAt,
        },
        "request completed",
      );
    });
    next();
  });

  app.get("/health", (_request, response) => {
    response.status(200).json({
      status: "ok",
      persistence: resolvePersistenceMode(),
    });
  });

  app.use(
    "/api/auth",
    createAuthRouter(services.authRouteService, services.jwtService),
  );
  app.use(
    "/api/devices",
    createDevicesRouter(services.deviceRouteService, services.jwtService),
  );
  app.use(
    "/api/companies",
    createCompaniesRouter(services.companyRouteService, services.jwtService),
  );
  app.use(
    "/api/users",
    createUsersRouter(services.usersRouteService, services.jwtService),
  );
  app.use(
    "/api/catalog",
    createCatalogRouter(services.catalogRouteService, services.jwtService),
  );
  app.use(
    "/api/inventory",
    createInventoryRouter(
      services.catalogRouteService,
      services.inventoryRouteService,
      services.jwtService,
    ),
  );
  app.use(
    "/api/purchases",
    createPurchasesRouter(
      services.purchasesRouteService,
      services.jwtService,
    ),
  );
  app.use(
    "/api/reports",
    createReportsRouter(services.reportsRouteService, services.jwtService),
  );
  app.use(
    "/api/suppliers",
    createSuppliersRouter(
      services.purchasesRouteService,
      services.jwtService,
    ),
  );
  app.use(
    "/api/sales",
    createSalesRouter(services.salesRouteService, services.jwtService),
  );
  app.use(
    "/api/receivables",
    createReceivablesRouter(
      services.receivableRouteService,
      services.jwtService,
    ),
  );
  app.use(
    "/api/cash",
    createCashRouter(services.syncCashRouteService, services.jwtService),
  );
  app.use(
    "/api/customers",
    createCrmRouter(services.crmRouteService, services.jwtService),
  );
  app.use(
    "/api/crm",
    createCrmAdminRouter(services.crmRouteService, services.jwtService),
  );
  app.use(
    "/api/sync",
    createSyncRouter(services.syncService, services.jwtService),
  );

  return app;
}
