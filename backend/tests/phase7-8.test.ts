import request from 'supertest';
import { describe, expect, it } from 'vitest';

import {
  createApp,
  createApplicationServices,
  type ApplicationServices,
} from '../src/app.js';

describe('phase 7 and 8 receivables, cash and CRM exports', () => {
  it('settles receivable notes idempotently through the receivables API', async () => {
    const services = createApplicationServices();
    const app = createApp(services);
    const customer = services.crmService.createCustomer({
      companyId: 'company_tatuzin',
      name: 'Cliente Fase 7',
      phone: '11977770000',
    });
    const sale = createNoteSale(services, customer.id);
    const note = services.receivableService.findBySale(
      'company_tatuzin',
      sale.sale.id,
    )!;

    const accessToken = await login(app, 'manager@tatuzin.app');

    const firstSettlement = await request(app)
      .post(`/api/receivables/${note.id}/settlements`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operationId: 'settlement-api-001',
        amountInCents: 4000,
        settlementMethod: 'cash',
        settledAt: '2026-04-22T10:00:00.000Z',
      });

    const secondSettlement = await request(app)
      .post(`/api/receivables/${note.id}/settlements`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operationId: 'settlement-api-001',
        amountInCents: 4000,
        settlementMethod: 'cash',
        settledAt: '2026-04-22T10:00:00.000Z',
      });

    expect(firstSettlement.status).toBe(201);
    expect(secondSettlement.status).toBe(200);
    expect(firstSettlement.body.note.paidAmountInCents).toBe(4000);
    expect(secondSettlement.body.duplicated).toBe(true);
    expect(
      services.receivableService.listSettlements(note.id),
    ).toHaveLength(1);
  });

  it('syncs receivable settlements without duplicating re-sent operations', async () => {
    const services = createApplicationServices();
    const app = createApp(services);
    const accessToken = await login(app, 'seller@tatuzin.app');

    const operations = [
      {
        operationId: 'phase7-qc-001',
        type: 'quick_customer',
        entityLocalId: 'customer_phase7_local',
        payload: {
          localId: 'customer_phase7_local',
          name: 'Cliente Sync Fase 7',
          phone: '11988880000',
          createdAt: '2026-04-22T08:00:00.000Z',
        },
      },
      {
        operationId: 'phase7-sale-001',
        type: 'sale',
        entityLocalId: 'sale_phase7_local',
        payload: {
          customerLocalId: 'customer_phase7_local',
          subtotalInCents: 12000,
          discountInCents: 0,
          totalInCents: 12000,
          createdAt: '2026-04-22T08:01:00.000Z',
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
              dueDate: '2026-05-22T00:00:00.000Z',
            },
          ],
        },
      },
      {
        operationId: 'phase7-settlement-001',
        type: 'receivable_settlement',
        entityLocalId: 'payment_phase7_local',
        payload: {
          paymentTermLocalId: 'term_phase7_local',
          saleLocalId: 'sale_phase7_local',
          amountInCents: 5000,
          settlementMethod: 'pix',
          paidAt: '2026-04-22T09:00:00.000Z',
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

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.results.map((item: { status: string }) => item.status)).toEqual([
      'processed',
      'processed',
      'processed',
    ]);
    expect(secondResponse.body.results.map((item: { status: string }) => item.status)).toEqual([
      'idempotent',
      'idempotent',
      'idempotent',
    ]);
    expect(firstResponse.body.results[2].data.note.paidAmountInCents).toBe(5000);
    expect(firstResponse.body.results[2].data.note.outstandingAmountInCents).toBe(
      7000,
    );
  });

  it('lists synced cash sessions and exports CRM segments as CSV', async () => {
    const services = createApplicationServices();
    const app = createApp(services);
    services.crmService.createCustomer({
      companyId: 'company_tatuzin',
      name: 'Ana CSV',
      phone: '11966660000',
      email: 'ana@tatuzin.app',
    });
    const cashierToken = await login(app, 'cashier@tatuzin.app');
    const crmToken = await login(app, 'crm@tatuzin.app');

    const syncResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        operations: [
          {
            operationId: 'cash-open-001',
            type: 'cash_movement',
            entityLocalId: 'cash_open_001',
            payload: {
              cashSessionLocalId: 'session_phase8_local',
              type: 'opening',
              amountInCents: 10000,
              openedAt: '2026-04-22T08:00:00.000Z',
            },
          },
          {
            operationId: 'cash-settlement-001',
            type: 'cash_movement',
            entityLocalId: 'cash_settlement_001',
            payload: {
              cashSessionLocalId: 'session_phase8_local',
              type: 'receivable_settlement_cash',
              amountInCents: 3000,
              createdAt: '2026-04-22T09:00:00.000Z',
            },
          },
          {
            operationId: 'cash-close-001',
            type: 'cash_movement',
            entityLocalId: 'cash_close_001',
            payload: {
              cashSessionLocalId: 'session_phase8_local',
              type: 'closing',
              amountInCents: 13000,
              createdAt: '2026-04-22T18:00:00.000Z',
            },
          },
        ],
      });

    const cashSessionsResponse = await request(app)
      .get('/api/cash/sessions')
      .set('Authorization', `Bearer ${cashierToken}`);
    const csvResponse = await request(app)
      .get('/api/crm/segments/export')
      .query({ format: 'csv', query: 'Ana' })
      .set('Authorization', `Bearer ${crmToken}`);

    expect(syncResponse.status).toBe(200);
    expect(cashSessionsResponse.status).toBe(200);
    expect(cashSessionsResponse.body.items[0].status).toBe('closed');
    expect(cashSessionsResponse.body.items[0].expectedCashBalanceInCents).toBe(
      13000,
    );
    expect(csvResponse.status).toBe(200);
    expect(csvResponse.text).toContain('id,name,phone,email');
    expect(csvResponse.text).toContain('Ana CSV');
  });

  it('opens, moves and closes cash sessions through the cash API', async () => {
    const services = createApplicationServices();
    const app = createApp(services);
    const cashierToken = await login(app, 'cashier@tatuzin.app');

    const openResponse = await request(app)
      .post('/api/cash/sessions/open')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        cashSessionLocalId: 'cash_api_session_001',
        openingAmountInCents: 5000,
        openedAt: '2026-04-22T08:00:00.000Z',
      });
    const movementResponse = await request(app)
      .post('/api/cash/movements')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        cashSessionLocalId: 'cash_api_session_001',
        type: 'sale_cash',
        amountInCents: 2500,
        createdAt: '2026-04-22T09:00:00.000Z',
      });
    const closeResponse = await request(app)
      .post('/api/cash/sessions/cash_api_session_001/close')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        closedAt: '2026-04-22T18:00:00.000Z',
      });
    const detailsResponse = await request(app)
      .get('/api/cash/sessions/cash_api_session_001')
      .set('Authorization', `Bearer ${cashierToken}`);

    expect(openResponse.status).toBe(201);
    expect(movementResponse.status).toBe(201);
    expect(closeResponse.status).toBe(200);
    expect(closeResponse.body.status).toBe('closed');
    expect(closeResponse.body.expectedCashBalanceInCents).toBe(7500);
    expect(detailsResponse.status).toBe(200);
    expect(detailsResponse.body.movements).toHaveLength(3);
  });
});

async function login(app: ReturnType<typeof createApp>, email: string) {
  const response = await request(app).post('/api/auth/login').send({
    email,
    password: 'tatuzin123',
  });
  expect(response.status).toBe(200);
  return response.body.tokens.accessToken as string;
}

function createNoteSale(services: ApplicationServices, customerId: string) {
  return services.salesService.createSale({
    companyId: 'company_tatuzin',
    userId: 'user_manager',
    customerId,
    subtotalInCents: 12000,
    discountInCents: 0,
    totalInCents: 12000,
    createdAt: '2026-04-22T08:30:00.000Z',
    items: [
      {
        variantId: 'var_bolsa_tiracolo_preta_u',
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
        dueDate: '2026-05-22T00:00:00.000Z',
      },
    ],
  });
}
