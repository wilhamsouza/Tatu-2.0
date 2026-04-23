import request from 'supertest';
import { describe, expect, it } from 'vitest';

import {
  createApp,
  createApplicationServices,
  type ApplicationServices,
} from '../src/app.js';

describe('sync routes', () => {
  it('ingests quick customer, sale and cash movement idempotently', async () => {
    const { app, accessToken } = await createAuthenticatedApp();

    const operations = [
      {
        operationId: 'op_quick_customer_1',
        type: 'quick_customer',
        entityLocalId: 'customer_local_1',
        payload: {
          localId: 'customer_local_1',
          name: 'Maria Sync',
          phone: '11999990000',
          createdAt: '2026-04-21T09:00:00.000Z',
        },
      },
      {
        operationId: 'op_sale_1',
        type: 'sale',
        entityLocalId: 'sale_local_1',
        payload: {
          localId: 'sale_local_1',
          customerLocalId: 'customer_local_1',
          subtotalInCents: 9900,
          discountInCents: 0,
          totalInCents: 9900,
          createdAt: '2026-04-21T09:01:00.000Z',
          items: [
            {
              localId: 'sale_item_local_1',
              displayName: 'Bolsa Tiracolo',
              quantity: 1,
              unitPriceInCents: 9900,
              totalPriceInCents: 9900,
            },
          ],
          payments: [
            {
              localId: 'payment_local_1',
              method: 'cash',
              amountInCents: 9900,
              changeInCents: 0,
              status: 'paid',
            },
          ],
        },
      },
      {
        operationId: 'op_cash_movement_1',
        type: 'cash_movement',
        entityLocalId: 'cash_movement_local_1',
        payload: {
          cashSessionLocalId: 'cash_session_local_1',
          saleLocalId: 'sale_local_1',
          type: 'sale_cash',
          amountInCents: 9900,
          createdAt: '2026-04-21T09:01:05.000Z',
        },
      },
    ];

    const firstResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ operations });

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.results).toHaveLength(3);
    expect(
      firstResponse.body.results.map(
        (result: { status: string }) => result.status,
      ),
    ).toEqual(['processed', 'processed', 'processed']);

    const remoteCustomerId = firstResponse.body.results[0].data.customer
      .id as string;
    expect(firstResponse.body.results[1].data.sale.customerId).toBe(
      remoteCustomerId,
    );
    expect(firstResponse.body.results[2].data.saleLocalId).toBe('sale_local_1');

    const secondResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ operations });

    expect(secondResponse.status).toBe(200);
    expect(
      secondResponse.body.results.map(
        (result: { status: string }) => result.status,
      ),
    ).toEqual(['idempotent', 'idempotent', 'idempotent']);
  });

  it('does not duplicate receivable note when sale already created it', async () => {
    const { app, accessToken, services } = await createAuthenticatedApp();

    const operations = [
      {
        operationId: 'op_quick_customer_note_1',
        type: 'quick_customer',
        entityLocalId: 'customer_local_note_1',
        payload: {
          localId: 'customer_local_note_1',
          name: 'Cliente Nota',
          phone: '11999991111',
          createdAt: '2026-04-21T09:10:00.000Z',
        },
      },
      {
        operationId: 'op_sale_note_1',
        type: 'sale',
        entityLocalId: 'sale_local_note_1',
        payload: {
          localId: 'sale_local_note_1',
          customerLocalId: 'customer_local_note_1',
          subtotalInCents: 9900,
          discountInCents: 0,
          totalInCents: 9900,
          createdAt: '2026-04-21T09:11:00.000Z',
          items: [
            {
              localId: 'sale_item_local_note_1',
              displayName: 'Bolsa Tiracolo',
              quantity: 1,
              unitPriceInCents: 9900,
              totalPriceInCents: 9900,
            },
          ],
          payments: [
            {
              localId: 'payment_local_note_1',
              method: 'note',
              amountInCents: 9900,
              dueDate: '2026-05-30T00:00:00.000Z',
              notes: 'Prazo de 30 dias',
            },
          ],
        },
      },
      {
        operationId: 'op_receivable_note_1',
        type: 'receivable_note',
        entityLocalId: 'payment_term_local_1',
        payload: {
          saleLocalId: 'sale_local_note_1',
          paymentTermLocalId: 'payment_term_local_1',
          customerLocalId: 'customer_local_note_1',
          originalAmountInCents: 9900,
          outstandingAmountInCents: 9900,
          dueDate: '2026-05-30T00:00:00.000Z',
          paymentStatus: 'pending',
          notes: 'Prazo de 30 dias',
        },
      },
    ];

    const response = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ operations });

    expect(response.status).toBe(200);
    expect(
      response.body.results.map((result: { status: string }) => result.status),
    ).toEqual(['processed', 'processed', 'idempotent']);

    const saleRemoteId = response.body.results[1].data.sale.id as string;
    const note = services.receivableService.findBySale(
      'company_tatuzin',
      saleRemoteId,
    );

    expect(note).toBeDefined();
    expect(note?.outstandingAmountInCents).toBe(9900);
    expect(note?.status).toBe('pending');
  });

  it('returns incremental updates by cursor', async () => {
    const { app, accessToken } = await createAuthenticatedApp();

    const firstResponse = await request(app)
      .get('/api/sync/updates')
      .set('Authorization', `Bearer ${accessToken}`)
      .query({ limit: 2 });

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.updates).toHaveLength(2);
    expect(firstResponse.body.updates[0].cursor).toBe('0001');
    expect(firstResponse.body.updates[1].cursor).toBe('0002');
    expect(firstResponse.body.nextCursor).toBe('0002');

    const secondResponse = await request(app)
      .get('/api/sync/updates')
      .set('Authorization', `Bearer ${accessToken}`)
      .query({ cursor: '0002', limit: 2 });

    expect(secondResponse.status).toBe(200);
    expect(secondResponse.body.updates).toHaveLength(2);
    expect(secondResponse.body.updates[0].cursor).toBe('0003');
    expect(secondResponse.body.updates[1].cursor).toBe('0004');
    expect(secondResponse.body.nextCursor).toBe('0004');
  });
});

async function createAuthenticatedApp(): Promise<{
  app: ReturnType<typeof createApp>;
  services: ApplicationServices;
  accessToken: string;
}> {
  const services = createApplicationServices();
  const app = createApp(services);

  const loginResponse = await request(app).post('/api/auth/login').send({
    email: 'seller@tatuzin.app',
    password: 'tatuzin123',
  });

  expect(loginResponse.status).toBe(200);

  return {
    app,
    services,
    accessToken: loginResponse.body.tokens.accessToken as string,
  };
}
