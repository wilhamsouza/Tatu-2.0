import { execFileSync } from 'node:child_process';
import path from 'node:path';

import { PrismaClient } from '@prisma/client';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { createApp, createApplicationServices } from '../src/app.js';
import { PrismaAuthService } from '../src/modules/auth/prisma-auth.service.js';
import { PrismaCatalogService } from '../src/modules/catalog/prisma-catalog.service.js';
import { PrismaCompanyService } from '../src/modules/companies/prisma-company.service.js';
import { PrismaCrmService } from '../src/modules/crm/prisma-crm.service.js';
import { PrismaDeviceService } from '../src/modules/devices/prisma-device.service.js';
import { PrismaInventoryService } from '../src/modules/inventory/prisma-inventory.service.js';
import { PrismaPurchasesService } from '../src/modules/purchases/prisma-purchases.service.js';
import { ReportsService } from '../src/modules/reports/reports.service.js';
import { PrismaReceivableService } from '../src/modules/sales/prisma-receivable.service.js';
import { PrismaSalesService } from '../src/modules/sales/prisma-sales.service.js';
import { PrismaSyncCashService } from '../src/modules/sync/prisma-sync-cash.service.js';
import { PrismaSyncCustomerService } from '../src/modules/sync/prisma-sync-customer.service.js';
import { PrismaSyncObservabilityService } from '../src/modules/sync/prisma-sync-observability.service.js';
import { SyncService } from '../src/modules/sync/sync.service.js';
import { PrismaUsersService } from '../src/modules/users/prisma-users.service.js';

const describeWithPostgres = describe.skipIf(
  process.env.TEST_DATABASE_URL == null,
);

describeWithPostgres('prisma catalog persistence', () => {
  const databaseUrl = process.env.TEST_DATABASE_URL ?? '';
  const previousDatabaseUrl = process.env.DATABASE_URL;
  let prisma: PrismaClient;

  beforeAll(async () => {
    process.env.DATABASE_URL = databaseUrl;
    execFileSync(
      process.execPath,
      [
        path.join(process.cwd(), 'node_modules', 'prisma', 'build', 'index.js'),
        'db',
        'push',
        '--force-reset',
        '--accept-data-loss',
        '--skip-generate',
      ],
      {
        cwd: process.cwd(),
        env: { ...process.env, DATABASE_URL: databaseUrl },
        stdio: 'inherit',
      },
    );

    prisma = new PrismaClient();
  }, 30000);

  afterAll(async () => {
    await prisma?.$disconnect();
    if (previousDatabaseUrl == null) {
      delete process.env.DATABASE_URL;
    } else {
      process.env.DATABASE_URL = previousDatabaseUrl;
    }

  }, 30000);

  it('persists catalog entities and builds sale snapshots from PostgreSQL', async () => {
    const service = new PrismaCatalogService(prisma);

    const initialCategories = await service.listCategories('company_tatuzin');
    expect(initialCategories.map((category) => category.id)).toContain(
      'cat_basicos',
    );

    const category = await service.createCategory({
      companyId: 'company_tatuzin',
      name: 'Persistida Prisma',
    });
    const product = await service.createProduct({
      companyId: 'company_tatuzin',
      name: 'Produto Persistido',
      categoryId: category.id,
    });
    const variant = await service.createVariant({
      companyId: 'company_tatuzin',
      productId: product.id,
      barcode: '7891234567890',
      sku: 'PRS-TST-M',
      color: 'Azul',
      size: 'M',
      priceInCents: 19900,
    });
    const updatedVariant = await service.updateVariant({
      companyId: 'company_tatuzin',
      id: variant.id,
      promotionalPriceInCents: 17900,
    });
    const snapshots = await service.buildSaleSnapshots('company_tatuzin');
    const storedVariant = await prisma.productVariant.findUnique({
      where: { id: variant.id },
    });

    expect(updatedVariant.promotionalPriceInCents).toBe(17900);
    expect(storedVariant?.sku).toBe('PRS-TST-M');
    expect(
      snapshots.variants.find((snapshot) => snapshot.id === variant.id),
    ).toMatchObject({
      displayName: 'Produto Persistido Azul M',
      priceInCents: 19900,
      promotionalPriceInCents: 17900,
      isActiveForSale: true,
    });
  });

  it('persists auth refresh sessions and device registrations through Prisma routes', async () => {
    const services = createApplicationServices();
    services.authRouteService = new PrismaAuthService(
      prisma,
      services.jwtService,
    );
    services.deviceRouteService = new PrismaDeviceService(prisma);
    services.companyRouteService = new PrismaCompanyService(prisma);
    services.usersRouteService = new PrismaUsersService(prisma);
    const app = createApp(services);
    const suffix = Date.now().toString();
    const deviceId = `device-prisma-${suffix}`;

    const login = await request(app).post('/api/auth/login').send({
      email: 'admin@tatuzin.app',
      password: 'tatuzin123',
    });
    const accessToken = login.body.tokens.accessToken as string;
    const refreshToken = login.body.tokens.refreshToken as string;
    const sessionCountAfterLogin = await prisma.refreshSession.count({
      where: { userId: 'user_admin' },
    });
    const storedMembership = await prisma.companyMembership.findFirst({
      where: {
        companyId: 'company_tatuzin',
        userId: 'user_admin',
      },
    });
    const companyResponse = await request(app)
      .get('/api/companies/current')
      .set('Authorization', `Bearer ${accessToken}`);
    const usersResponse = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${accessToken}`);
    const createdUserResponse = await request(app)
      .post('/api/users')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Usuario Prisma',
        email: `usuario.prisma.${suffix}@tatuzin.app`,
        password: 'tatuzin123',
        roles: ['seller', 'cashier'],
      });
    const updatedUserResponse = await request(app)
      .put(`/api/users/${createdUserResponse.body.id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Usuario Prisma Atualizado',
        roles: ['manager'],
      });
    const storedUserMemberships = await prisma.companyMembership.findMany({
      where: {
        companyId: 'company_tatuzin',
        userId: createdUserResponse.body.id,
      },
    });
    const companyUpdateResponse = await request(app)
      .put('/api/companies/current')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: `Tatuzin Prisma ${suffix}` });
    const storedCompany = await prisma.company.findUnique({
      where: { id: 'company_tatuzin' },
    });

    const firstDeviceResponse = await request(app)
      .post('/api/devices/register')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        deviceId,
        platform: 'android',
        appVersion: '2.0.0',
      });
    const secondDeviceResponse = await request(app)
      .post('/api/devices/register')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        deviceId,
        platform: 'android',
        appVersion: '2.0.1',
      });
    const storedDeviceCount = await prisma.device.count({
      where: {
        companyId: 'company_tatuzin',
        deviceIdentifier: deviceId,
      },
    });

    const refreshResponse = await request(app).post('/api/auth/refresh').send({
      refreshToken,
    });
    const refreshedToken = refreshResponse.body.tokens.refreshToken as string;
    const sessionCountAfterRefresh = await prisma.refreshSession.count({
      where: { userId: 'user_admin' },
    });

    const logoutResponse = await request(app).post('/api/auth/logout').send({
      refreshToken: refreshedToken,
    });
    const sessionCountAfterLogout = await prisma.refreshSession.count({
      where: { userId: 'user_admin' },
    });

    expect(login.status).toBe(200);
    expect(login.body.user).toMatchObject({
      userId: 'user_admin',
      companyId: 'company_tatuzin',
      roles: ['admin'],
    });
    expect(storedMembership?.role).toBe('ADMIN');
    expect(sessionCountAfterLogin).toBe(1);
    expect(companyResponse.body.name).toBe('Tatuzin Moda');
    expect(usersResponse.body.items.length).toBeGreaterThanOrEqual(5);
    expect(createdUserResponse.status).toBe(201);
    expect(createdUserResponse.body.roles).toEqual(['cashier', 'seller']);
    expect(updatedUserResponse.status).toBe(200);
    expect(updatedUserResponse.body).toMatchObject({
      name: 'Usuario Prisma Atualizado',
      roles: ['manager'],
    });
    expect(storedUserMemberships.map((membership) => membership.role)).toEqual([
      'MANAGER',
    ]);
    expect(companyUpdateResponse.status).toBe(200);
    expect(storedCompany?.name).toBe(`Tatuzin Prisma ${suffix}`);
    expect(firstDeviceResponse.status).toBe(201);
    expect(secondDeviceResponse.status).toBe(201);
    expect(secondDeviceResponse.body.id).toBe(firstDeviceResponse.body.id);
    expect(secondDeviceResponse.body.appVersion).toBe('2.0.1');
    expect(storedDeviceCount).toBe(1);
    expect(refreshResponse.status).toBe(200);
    expect(refreshedToken).not.toBe(refreshToken);
    expect(sessionCountAfterRefresh).toBe(1);
    expect(logoutResponse.status).toBe(204);
    expect(sessionCountAfterLogout).toBe(0);
  });

  it('serves catalog and inventory routes from the Prisma catalog service', async () => {
    const services = createApplicationServices();
    services.catalogRouteService = new PrismaCatalogService(prisma);
    const app = createApp(services);
    const login = await request(app).post('/api/auth/login').send({
      email: 'manager@tatuzin.app',
      password: 'tatuzin123',
    });
    const accessToken = login.body.tokens.accessToken as string;

    const categoryResponse = await request(app)
      .post('/api/catalog/categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'Categoria Rota Prisma' });
    const productResponse = await request(app)
      .post('/api/catalog/products')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Produto Rota Prisma',
        categoryId: categoryResponse.body.id,
      });
    const variantResponse = await request(app)
      .post('/api/catalog/variants')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        productId: productResponse.body.id,
        sku: 'ROTA-PRS-M',
        color: 'Verde',
        size: 'M',
        priceInCents: 21900,
      });
    const inventoryResponse = await request(app)
      .get('/api/inventory/summary')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(categoryResponse.status).toBe(201);
    expect(productResponse.status).toBe(201);
    expect(variantResponse.status).toBe(201);
    expect(
      inventoryResponse.body.items.find(
        (item: { variantId: string }) => item.variantId === variantResponse.body.id,
      ),
    ).toMatchObject({
      productName: 'Produto Rota Prisma',
      quantityOnHand: 0,
    });
  });

  it('persists purchases, receipts and inventory movements through Prisma services', async () => {
    const catalogService = new PrismaCatalogService(prisma);
    const inventoryService = new PrismaInventoryService(prisma);
    const services = createApplicationServices();
    services.catalogRouteService = catalogService;
    services.inventoryRouteService = inventoryService;
    services.purchasesRouteService = new PrismaPurchasesService(
      prisma,
      catalogService,
    );
    const app = createApp(services);
    const login = await request(app).post('/api/auth/login').send({
      email: 'manager@tatuzin.app',
      password: 'tatuzin123',
    });
    const accessToken = login.body.tokens.accessToken as string;
    const suffix = Date.now().toString();

    const categoryResponse = await request(app)
      .post('/api/catalog/categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: `Categoria ERP Prisma ${suffix}` });
    const productResponse = await request(app)
      .post('/api/catalog/products')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: `Produto ERP Prisma ${suffix}`,
        categoryId: categoryResponse.body.id,
      });
    const variantResponse = await request(app)
      .post('/api/catalog/variants')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        productId: productResponse.body.id,
        sku: `ERP-PRS-${suffix}`,
        color: 'Cinza',
        size: 'G',
        priceInCents: 18900,
      });
    const supplierResponse = await request(app)
      .post('/api/suppliers')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: `Fornecedor Prisma ${suffix}`,
        phone: '11999998888',
      });
    const purchaseResponse = await request(app)
      .post('/api/purchases')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        supplierId: supplierResponse.body.id,
        notes: 'Compra persistida em Prisma',
        items: [
          {
            variantId: variantResponse.body.id,
            quantityOrdered: 4,
            unitCostInCents: 12000,
          },
        ],
      });

    expect(purchaseResponse.status).toBe(201);
    expect(purchaseResponse.body.status).toBe('pending');

    const firstReceiveResponse = await request(app)
      .post(`/api/purchases/${purchaseResponse.body.id}/receive`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        items: [
          {
            purchaseItemId: purchaseResponse.body.items[0].id,
            quantityReceived: 2,
          },
        ],
      });

    expect(firstReceiveResponse.status).toBe(200);
    expect(firstReceiveResponse.body.status).toBe('partially_received');
    expect(firstReceiveResponse.body.items[0].quantityReceived).toBe(2);

    const secondReceiveResponse = await request(app)
      .post(`/api/purchases/${purchaseResponse.body.id}/receive`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        items: [
          {
            purchaseItemId: purchaseResponse.body.items[0].id,
            quantityReceived: 2,
          },
        ],
      });
    const inventoryVariantResponse = await request(app)
      .get(`/api/inventory/variants/${variantResponse.body.id}`)
      .set('Authorization', `Bearer ${accessToken}`);
    const storedBalance = await prisma.inventoryBalance.findUnique({
      where: {
        companyId_variantId: {
          companyId: 'company_tatuzin',
          variantId: variantResponse.body.id,
        },
      },
    });
    const movementCount = await prisma.stockMovement.count({
      where: {
        companyId: 'company_tatuzin',
        referenceId: purchaseResponse.body.id,
        variantId: variantResponse.body.id,
      },
    });

    expect(secondReceiveResponse.status).toBe(200);
    expect(secondReceiveResponse.body.status).toBe('received');
    expect(inventoryVariantResponse.body.quantityOnHand).toBe(4);
    expect(storedBalance?.quantityOnHand).toBe(4);
    expect(movementCount).toBe(2);
  });

  it('persists sales, receivable notes and settlements through Prisma routes', async () => {
    const receivableService = new PrismaReceivableService(prisma);
    const services = createApplicationServices();
    services.receivableRouteService = receivableService;
    services.salesRouteService = new PrismaSalesService(
      prisma,
      receivableService,
    );
    const app = createApp(services);
    const login = await request(app).post('/api/auth/login').send({
      email: 'manager@tatuzin.app',
      password: 'tatuzin123',
    });
    const accessToken = login.body.tokens.accessToken as string;
    const suffix = Date.now().toString();
    const customer = await prisma.customer.create({
      data: {
        id: `customer_prisma_sale_${suffix}`,
        companyId: 'company_tatuzin',
        name: 'Cliente Venda Prisma',
        phone: `1197${suffix.slice(-7)}`,
        source: 'manual',
      },
    });
    const salePayload = {
      operationId: `prisma-sale-note-${suffix}`,
      customerId: customer.id,
      subtotalInCents: 15000,
      discountInCents: 1000,
      totalInCents: 14000,
      createdAt: '2026-04-22T13:00:00.000Z',
      items: [
        {
          displayName: 'Venda Prisma em Nota',
          quantity: 1,
          unitPriceInCents: 15000,
          totalPriceInCents: 15000,
        },
      ],
      payments: [
        {
          method: 'note',
          amountInCents: 14000,
          dueDate: '2026-05-22T00:00:00.000Z',
          notes: 'Prazo Prisma',
        },
      ],
    };

    const firstSaleResponse = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(salePayload);
    const secondSaleResponse = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(salePayload);
    const saleId = firstSaleResponse.body.sale.id as string;
    const noteId = firstSaleResponse.body.receivableNotes[0].id as string;
    const saleDetailsResponse = await request(app)
      .get(`/api/sales/${saleId}`)
      .set('Authorization', `Bearer ${accessToken}`);
    const listReceivablesResponse = await request(app)
      .get('/api/receivables')
      .query({ customerId: customer.id })
      .set('Authorization', `Bearer ${accessToken}`);
    const firstSettlementResponse = await request(app)
      .post(`/api/receivables/${noteId}/settlements`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operationId: `prisma-settlement-${suffix}`,
        amountInCents: 5000,
        settlementMethod: 'pix',
        settledAt: '2026-04-22T14:00:00.000Z',
      });
    const secondSettlementResponse = await request(app)
      .post(`/api/receivables/${noteId}/settlements`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operationId: `prisma-settlement-${suffix}`,
        amountInCents: 5000,
        settlementMethod: 'pix',
        settledAt: '2026-04-22T14:00:00.000Z',
      });
    const cancelResponse = await request(app)
      .post(`/api/sales/${saleId}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});
    const persistedSaleCount = await prisma.sale.count({
      where: {
        companyId: 'company_tatuzin',
        operationId: salePayload.operationId,
      },
    });
    const persistedSettlementCount = await prisma.receivableSettlement.count({
      where: {
        receivableNoteId: noteId,
        operationId: `prisma-settlement-${suffix}`,
      },
    });

    expect(firstSaleResponse.status).toBe(201);
    expect(secondSaleResponse.status).toBe(200);
    expect(secondSaleResponse.body.duplicated).toBe(true);
    expect(firstSaleResponse.body.receivableNotes[0]).toMatchObject({
      originalAmountInCents: 14000,
      outstandingAmountInCents: 14000,
      status: 'pending',
    });
    expect(saleDetailsResponse.body.status).toBe('completed');
    expect(listReceivablesResponse.body.items).toHaveLength(1);
    expect(firstSettlementResponse.status).toBe(201);
    expect(firstSettlementResponse.body.note).toMatchObject({
      paidAmountInCents: 5000,
      outstandingAmountInCents: 9000,
      status: 'partially_paid',
    });
    expect(secondSettlementResponse.status).toBe(200);
    expect(secondSettlementResponse.body.duplicated).toBe(true);
    expect(cancelResponse.body.status).toBe('canceled');
    expect(persistedSaleCount).toBe(1);
    expect(persistedSettlementCount).toBe(1);
  });

  it('syncs quick customer, note sale and settlement through Prisma services', async () => {
    const catalogService = new PrismaCatalogService(prisma);
    await catalogService.listVariants('company_tatuzin');

    const receivableService = new PrismaReceivableService(prisma);
    const salesService = new PrismaSalesService(prisma, receivableService);
    const syncCustomerService = new PrismaSyncCustomerService(prisma);
    const services = createApplicationServices();
    services.catalogRouteService = catalogService;
    services.receivableRouteService = receivableService;
    services.salesRouteService = salesService;
    services.syncCustomerRouteService = syncCustomerService;
    services.syncService = new SyncService(
      salesService,
      receivableService,
      syncCustomerService,
      services.syncCashService,
      services.syncUpdatesService,
    );
    const app = createApp(services);
    const login = await request(app).post('/api/auth/login').send({
      email: 'seller@tatuzin.app',
      password: 'tatuzin123',
    });
    const accessToken = login.body.tokens.accessToken as string;
    const suffix = Date.now().toString();
    const operations = [
      {
        operationId: `prisma-sync-qc-${suffix}`,
        type: 'quick_customer',
        entityLocalId: `customer_prisma_sync_${suffix}`,
        payload: {
          name: 'Cliente Sync Prisma',
          phone: `1198${suffix.slice(-7)}`,
          createdAt: '2026-04-22T15:00:00.000Z',
        },
      },
      {
        operationId: `prisma-sync-sale-${suffix}`,
        type: 'sale',
        entityLocalId: `sale_prisma_sync_${suffix}`,
        payload: {
          customerLocalId: `customer_prisma_sync_${suffix}`,
          subtotalInCents: 15900,
          discountInCents: 0,
          totalInCents: 15900,
          createdAt: '2026-04-22T15:05:00.000Z',
          items: [
            {
              variantRemoteId: 'var_bolsa_tiracolo_preta_u',
              displayName: 'Bolsa Tiracolo Preta U',
              quantity: 1,
              unitPriceInCents: 15900,
              totalPriceInCents: 15900,
            },
          ],
          payments: [
            {
              method: 'note',
              amountInCents: 15900,
              dueDate: '2026-05-22T00:00:00.000Z',
              notes: 'Sync Prisma nota',
            },
          ],
        },
      },
      {
        operationId: `prisma-sync-note-${suffix}`,
        type: 'receivable_note',
        entityLocalId: `term_prisma_sync_${suffix}`,
        payload: {
          saleLocalId: `sale_prisma_sync_${suffix}`,
          customerLocalId: `customer_prisma_sync_${suffix}`,
          originalAmountInCents: 15900,
          dueDate: '2026-05-22T00:00:00.000Z',
          notes: 'Sync Prisma nota',
        },
      },
      {
        operationId: `prisma-sync-settlement-${suffix}`,
        type: 'receivable_settlement',
        entityLocalId: `settlement_prisma_sync_${suffix}`,
        payload: {
          saleLocalId: `sale_prisma_sync_${suffix}`,
          amountInCents: 5900,
          settlementMethod: 'cash',
          paidAt: '2026-04-22T16:00:00.000Z',
        },
      },
    ];

    const firstResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ operations });
    const secondResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ operations });
    const saleId = firstResponse.body.results[1].data.sale.id as string;
    const noteId = firstResponse.body.results[1].data.receivableNotes[0]
      .id as string;
    const persistedSaleCount = await prisma.sale.count({
      where: {
        companyId: 'company_tatuzin',
        operationId: `prisma-sync-sale-${suffix}`,
      },
    });
    const persistedNote = await prisma.receivableNote.findUnique({
      where: { id: noteId },
    });
    const persistedSettlementCount = await prisma.receivableSettlement.count({
      where: {
        receivableNoteId: noteId,
        operationId: `prisma-sync-settlement-${suffix}`,
      },
    });

    expect(firstResponse.status).toBe(200);
    expect(
      firstResponse.body.results.map((result: { status: string }) => result.status),
    ).toEqual(['processed', 'processed', 'idempotent', 'processed']);
    expect(
      secondResponse.body.results.map((result: { status: string }) => result.status),
    ).toEqual(['idempotent', 'idempotent', 'idempotent', 'idempotent']);
    expect(firstResponse.body.results[1].data.sale.customerId).toBeDefined();
    expect(firstResponse.body.results[2].data.note.id).toBe(noteId);
    expect(firstResponse.body.results[3].data.note.paidAmountInCents).toBe(
      5900,
    );
    expect(persistedSaleCount).toBe(1);
    expect(persistedNote?.saleId).toBe(saleId);
    expect(persistedNote?.outstandingAmountInCents).toBe(10000);
    expect(persistedSettlementCount).toBe(1);
  });

  it('serves CRM summaries and reports from Prisma persisted sales', async () => {
    const catalogService = new PrismaCatalogService(prisma);
    await catalogService.listVariants('company_tatuzin');

    const receivableService = new PrismaReceivableService(prisma);
    const salesService = new PrismaSalesService(prisma, receivableService);
    const syncCustomerService = new PrismaSyncCustomerService(prisma);
    const services = createApplicationServices();
    services.catalogRouteService = catalogService;
    services.receivableRouteService = receivableService;
    services.salesRouteService = salesService;
    services.syncCustomerRouteService = syncCustomerService;
    services.crmRouteService = new PrismaCrmService(prisma);
    services.reportsRouteService = new ReportsService(
      catalogService,
      salesService,
      receivableService,
    );
    services.syncService = new SyncService(
      salesService,
      receivableService,
      syncCustomerService,
      services.syncCashService,
      services.syncUpdatesService,
    );
    const app = createApp(services);
    const sellerLogin = await request(app).post('/api/auth/login').send({
      email: 'seller@tatuzin.app',
      password: 'tatuzin123',
    });
    const managerLogin = await request(app).post('/api/auth/login').send({
      email: 'manager@tatuzin.app',
      password: 'tatuzin123',
    });
    const crmLogin = await request(app).post('/api/auth/login').send({
      email: 'crm@tatuzin.app',
      password: 'tatuzin123',
    });
    const sellerToken = sellerLogin.body.tokens.accessToken as string;
    const managerToken = managerLogin.body.tokens.accessToken as string;
    const crmToken = crmLogin.body.tokens.accessToken as string;
    const suffix = Date.now().toString();
    const customerLocalId = `crm_report_customer_${suffix}`;
    const saleLocalId = `crm_report_sale_${suffix}`;

    const syncResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        operations: [
          {
            operationId: `crm-report-qc-${suffix}`,
            type: 'quick_customer',
            entityLocalId: customerLocalId,
            payload: {
              name: 'Cliente CRM Prisma',
              phone: `1196${suffix.slice(-7)}`,
              createdAt: '2026-04-23T10:00:00.000Z',
            },
          },
          {
            operationId: `crm-report-sale-${suffix}`,
            type: 'sale',
            entityLocalId: saleLocalId,
            payload: {
              customerLocalId,
              subtotalInCents: 12000,
              discountInCents: 0,
              totalInCents: 12000,
              createdAt: '2026-04-23T10:05:00.000Z',
              items: [
                {
                  variantRemoteId: 'var_bolsa_tiracolo_preta_u',
                  displayName: 'Bolsa Tiracolo Preta U',
                  quantity: 1,
                  unitPriceInCents: 12000,
                  totalPriceInCents: 12000,
                },
              ],
              payments: [
                {
                  method: 'note',
                  amountInCents: 12000,
                  dueDate: '2026-05-23T00:00:00.000Z',
                },
              ],
            },
          },
          {
            operationId: `crm-report-settlement-${suffix}`,
            type: 'receivable_settlement',
            entityLocalId: `crm_report_settlement_${suffix}`,
            payload: {
              saleLocalId,
              amountInCents: 5000,
              settlementMethod: 'pix',
              paidAt: '2026-04-23T11:00:00.000Z',
            },
          },
        ],
      });
    const customersResponse = await request(app)
      .get('/api/customers')
      .query({ query: 'Cliente CRM Prisma' })
      .set('Authorization', `Bearer ${crmToken}`);
    const customerId = customersResponse.body.items[0].id as string;
    const historyResponse = await request(app)
      .get(`/api/customers/${customerId}/history`)
      .set('Authorization', `Bearer ${crmToken}`);
    const summaryResponse = await request(app)
      .get(`/api/customers/${customerId}/summary`)
      .set('Authorization', `Bearer ${crmToken}`);
    const receivablesResponse = await request(app)
      .get(`/api/customers/${customerId}/receivables`)
      .set('Authorization', `Bearer ${crmToken}`);
    const csvResponse = await request(app)
      .get('/api/crm/segments/export')
      .query({ query: 'Cliente CRM Prisma' })
      .set('Authorization', `Bearer ${crmToken}`);
    const reportsResponse = await request(app)
      .get('/api/reports/dashboard')
      .query({
        referenceDate: '2026-04-23T18:00:00.000Z',
        rankingLimit: 3,
      })
      .set('Authorization', `Bearer ${managerToken}`);

    expect(syncResponse.status).toBe(200);
    expect(
      syncResponse.body.results.map((result: { status: string }) => result.status),
    ).toEqual(['processed', 'processed', 'processed']);
    expect(customersResponse.status).toBe(200);
    expect(customersResponse.body.items).toHaveLength(1);
    expect(customersResponse.body.items[0]).toMatchObject({
      totalPurchases: 1,
      totalSpentInCents: 12000,
      totalOutstandingInCents: 7000,
      openReceivablesCount: 1,
    });
    expect(historyResponse.body.purchases[0]).toMatchObject({
      totalInCents: 12000,
      outstandingAmountInCents: 7000,
      receivableStatus: 'partially_paid',
    });
    expect(summaryResponse.body).toMatchObject({
      totalPurchases: 1,
      totalSpentInCents: 12000,
      averageTicketInCents: 12000,
      totalOutstandingInCents: 7000,
      openReceivablesCount: 1,
    });
    expect(receivablesResponse.body.items[0]).toMatchObject({
      paidAmountInCents: 5000,
      outstandingAmountInCents: 7000,
      status: 'partially_paid',
    });
    expect(csvResponse.text).toContain('Cliente CRM Prisma');
    expect(reportsResponse.body.reports.daily).toMatchObject({
      salesCount: 1,
      netRevenueInCents: 12000,
      noteRevenueInCents: 12000,
    });
    expect(reportsResponse.body.reports.daily.openReceivablesInCents).toBeGreaterThanOrEqual(
      7000,
    );
    expect(
      reportsResponse.body.reports.daily.openReceivablesCount,
    ).toBeGreaterThanOrEqual(1);
    expect(reportsResponse.body.reports.daily.topProducts[0].label).toBe(
      'Bolsa Tiracolo',
    );
  });

  it('persists cash sessions, sync logs and conflicts through Prisma', async () => {
    const services = createApplicationServices();
    const cashService = new PrismaSyncCashService(prisma);
    const observer = new PrismaSyncObservabilityService(prisma);
    services.syncCashRouteService = cashService;
    services.syncService = new SyncService(
      services.salesRouteService,
      services.receivableRouteService,
      services.syncCustomerRouteService,
      cashService,
      services.syncUpdatesService,
      observer,
    );
    const app = createApp(services);
    const login = await request(app).post('/api/auth/login').send({
      email: 'cashier@tatuzin.app',
      password: 'tatuzin123',
    });
    const accessToken = login.body.tokens.accessToken as string;
    const suffix = Date.now().toString();
    const cashSessionLocalId = `cash_prisma_${suffix}`;
    const operations = [
      {
        operationId: `cash-prisma-open-${suffix}`,
        type: 'cash_movement',
        entityLocalId: `cash_open_${suffix}`,
        payload: {
          cashSessionLocalId,
          type: 'opening',
          amountInCents: 10000,
          openedAt: '2026-04-24T08:00:00.000Z',
        },
      },
      {
        operationId: `cash-prisma-settlement-${suffix}`,
        type: 'cash_movement',
        entityLocalId: `cash_settlement_${suffix}`,
        payload: {
          cashSessionLocalId,
          type: 'receivable_settlement_cash',
          amountInCents: 3000,
          createdAt: '2026-04-24T09:00:00.000Z',
        },
      },
      {
        operationId: `cash-prisma-close-${suffix}`,
        type: 'cash_movement',
        entityLocalId: `cash_close_${suffix}`,
        payload: {
          cashSessionLocalId,
          type: 'closing',
          amountInCents: 0,
          createdAt: '2026-04-24T18:00:00.000Z',
        },
      },
      {
        operationId: `cash-prisma-conflict-${suffix}`,
        type: 'cash_movement',
        entityLocalId: `cash_conflict_${suffix}`,
        payload: {
          cashSessionLocalId: `cash_conflict_session_${suffix}`,
          type: 'sale_cash',
          amountInCents: -1,
          createdAt: '2026-04-24T19:00:00.000Z',
        },
      },
    ];

    const syncResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ operations });
    const sessionsResponse = await request(app)
      .get('/api/cash/sessions')
      .set('Authorization', `Bearer ${accessToken}`);
    const detailsResponse = await request(app)
      .get(`/api/cash/sessions/${cashSessionLocalId}`)
      .set('Authorization', `Bearer ${accessToken}`);
    const storedSession = await prisma.cashSessionRemote.findUnique({
      where: {
        companyId_cashSessionLocalId: {
          companyId: 'company_tatuzin',
          cashSessionLocalId,
        },
      },
    });
    const storedMovementCount = await prisma.cashMovementRemote.count({
      where: {
        companyId: 'company_tatuzin',
        cashSessionLocalId,
      },
    });
    const storedLogs = await prisma.syncOperationLog.findMany({
      where: {
        companyId: 'company_tatuzin',
        operationId: { in: operations.map((operation) => operation.operationId) },
      },
      orderBy: { operationId: 'asc' },
    });
    const storedConflict = await prisma.syncConflict.findFirst({
      where: {
        companyId: 'company_tatuzin',
        operationId: `cash-prisma-conflict-${suffix}`,
      },
    });

    expect(syncResponse.status).toBe(200);
    expect(
      syncResponse.body.results.map((result: { status: string }) => result.status),
    ).toEqual(['processed', 'processed', 'processed', 'conflict']);
    expect(
      sessionsResponse.body.items.find(
        (item: { cashSessionLocalId: string }) =>
          item.cashSessionLocalId === cashSessionLocalId,
      ),
    ).toMatchObject({
      status: 'closed',
      expectedCashBalanceInCents: 13000,
      movementCount: 3,
    });
    expect(detailsResponse.body.movements).toHaveLength(3);
    expect(storedSession?.status).toBe('CLOSED');
    expect(storedMovementCount).toBe(3);
    expect(storedLogs).toHaveLength(4);
    expect(
      storedLogs.filter((log) => log.status === 'SYNCED'),
    ).toHaveLength(3);
    expect(
      storedLogs.find(
        (log) => log.operationId === `cash-prisma-conflict-${suffix}`,
      )?.status,
    ).toBe('CONFLICT');
    expect(storedConflict).toMatchObject({
      type: 'cash_movement_invalid',
      message: 'Cash movement amount cannot be negative.',
    });
  });
});
