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

describe('sync bridge', () => {
  it('processes quick customer, sale, cash movement and receivable note in order', async () => {
    const { app, accessToken } = await authenticateSeller();

    const response = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        operations: [
          {
            operationId: 'sync-qc-001',
            type: 'quick_customer',
            entityLocalId: 'customer_local_001',
            payload: {
              localId: 'customer_local_001',
              name: 'Maria Sync',
              phone: '11999990000',
              createdAt: '2026-04-21T10:00:00.000Z',
            },
          },
          {
            operationId: 'sync-sale-note-001',
            type: 'sale',
            entityLocalId: 'sale_local_001',
            payload: {
              customerLocalId: 'customer_local_001',
              subtotalInCents: 15000,
              discountInCents: 0,
              totalInCents: 15000,
              createdAt: '2026-04-21T10:01:00.000Z',
              items: [
                {
                  variantRemoteId: 'variant_001',
                  displayName: 'Vestido Midi',
                  quantity: 1,
                  unitPriceInCents: 15000,
                  totalPriceInCents: 15000,
                },
              ],
              payments: [
                {
                  method: 'note',
                  amountInCents: 15000,
                  dueDate: '2026-05-10T00:00:00.000Z',
                  notes: 'Prazo 30 dias',
                },
              ],
            },
          },
          {
            operationId: 'sync-cash-001',
            type: 'cash_movement',
            entityLocalId: 'cash_local_001',
            payload: {
              cashSessionLocalId: 'cash_session_local_001',
              saleLocalId: 'sale_local_001',
              type: 'sale_note',
              amountInCents: 15000,
              createdAt: '2026-04-21T10:01:00.000Z',
            },
          },
          {
            operationId: 'sync-note-001',
            type: 'receivable_note',
            entityLocalId: 'payment_term_local_001',
            payload: {
              saleLocalId: 'sale_local_001',
              customerLocalId: 'customer_local_001',
              originalAmountInCents: 15000,
              dueDate: '2026-05-10T00:00:00.000Z',
              notes: 'Prazo 30 dias',
              createdAt: '2026-04-21T10:01:00.000Z',
            },
          },
        ],
      });

    expect(response.status).toBe(200);
    expect(response.body.results[0].status).toBe('processed');
    expect(response.body.results[1].status).toBe('processed');
    expect(response.body.results[2].status).toBe('processed');
    expect(response.body.results[3].status).toBe('idempotent');
    expect(response.body.results[1].data.sale.customerId).toBeDefined();
    expect(response.body.results[3].data.note.id).toBe(
      response.body.results[1].data.receivableNotes[0].id,
    );
  });

  it('returns incremental catalog updates after the provided cursor', async () => {
    const { app, accessToken } = await authenticateSeller();

    const response = await request(app)
      .get('/api/sync/updates')
      .query({ cursor: '0002', limit: 10 })
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.updates).toHaveLength(2);
    expect(response.body.updates[0].updateType).toBe('variant_snapshot');
    expect(response.body.nextCursor).toBe('0004');
  });
});
