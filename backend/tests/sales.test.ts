import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from '../src/app.js';

async function authenticateSeller() {
  const app = createApp();
  const login = await request(app).post('/api/auth/login').send({
    email: 'seller@tatuzin.app',
    password: 'tatuzin123',
  });

  return {
    app,
    accessToken: login.body.tokens.accessToken as string,
  };
}

async function authenticateManager() {
  const app = createApp();
  const login = await request(app).post('/api/auth/login').send({
    email: 'manager@tatuzin.app',
    password: 'tatuzin123',
  });

  return {
    app,
    accessToken: login.body.tokens.accessToken as string,
  };
}

describe('sales and sync', () => {
  it('creates a receivable note when a sale uses note payment', async () => {
    const { app, accessToken } = await authenticateSeller();

    const response = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operationId: 'op-sale-note-001',
        customerId: 'customer_001',
        subtotalInCents: 15000,
        discountInCents: 0,
        totalInCents: 15000,
        items: [
          {
            variantId: 'variant_001',
            displayName: 'Camiseta Oversized Preta',
            quantity: 1,
            unitPriceInCents: 15000,
            totalPriceInCents: 15000,
          },
        ],
        payments: [
          {
            method: 'note',
            amountInCents: 15000,
            dueDate: '2026-05-05T00:00:00.000Z',
          },
        ],
      });

    expect(response.status).toBe(201);
    expect(response.body.receivableNotes).toHaveLength(1);
    expect(response.body.receivableNotes[0].status).toBe('pending');
    expect(response.body.receivableNotes[0].outstandingAmountInCents).toBe(15000);
  });

  it('treats the same outbox operation as idempotent when resent', async () => {
    const { app, accessToken } = await authenticateSeller();

    const payload = {
      operations: [
        {
          operationId: 'sync-sale-001',
          type: 'sale',
          entityLocalId: 'sale_local_001',
          payload: {
            customerId: 'customer_001',
            subtotalInCents: 9000,
            discountInCents: 0,
            totalInCents: 9000,
            items: [
              {
                displayName: 'Regata Branca',
                quantity: 1,
                unitPriceInCents: 9000,
                totalPriceInCents: 9000,
              },
            ],
            payments: [
              {
                method: 'cash',
                amountInCents: 9000,
              },
            ],
          },
        },
      ],
    };

    const firstResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(payload);

    const secondResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send(payload);

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.body.results[0].status).toBe('processed');
    expect(secondResponse.status).toBe(200);
    expect(secondResponse.body.results[0].status).toBe('idempotent');
    expect(secondResponse.body.results[0].data.sale.id).toBe(
      firstResponse.body.results[0].data.sale.id,
    );
  });

  it('lists, details and cancels sales through protected sales routes', async () => {
    const { app, accessToken } = await authenticateManager();

    const createdResponse = await request(app)
      .post('/api/sales')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operationId: 'sale-admin-flow-001',
        subtotalInCents: 9900,
        discountInCents: 0,
        totalInCents: 9900,
        items: [
          {
            variantId: 'var_camiseta_oversized_preta_m',
            displayName: 'Camiseta Oversized Preta M',
            quantity: 1,
            unitPriceInCents: 9900,
            totalPriceInCents: 9900,
          },
        ],
        payments: [
          {
            method: 'cash',
            amountInCents: 9900,
          },
        ],
      });

    expect(createdResponse.status).toBe(201);
    const saleId = createdResponse.body.sale.id as string;

    const listResponse = await request(app)
      .get('/api/sales')
      .set('Authorization', `Bearer ${accessToken}`);
    const detailResponse = await request(app)
      .get(`/api/sales/${saleId}`)
      .set('Authorization', `Bearer ${accessToken}`);
    const cancelResponse = await request(app)
      .post(`/api/sales/${saleId}/cancel`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({});

    expect(listResponse.status).toBe(200);
    expect(
      listResponse.body.items.some((sale: { id: string }) => sale.id === saleId),
    ).toBe(true);
    expect(detailResponse.status).toBe(200);
    expect(detailResponse.body.status).toBe('completed');
    expect(cancelResponse.status).toBe(200);
    expect(cancelResponse.body.status).toBe('canceled');
  });
});
