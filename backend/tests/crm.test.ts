import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from '../src/app.js';

async function authenticate(app: ReturnType<typeof createApp>, email: string) {
  const response = await request(app).post('/api/auth/login').send({
    email,
    password: 'tatuzin123',
  });

  expect(response.status).toBe(200);
  return response.body.tokens.accessToken as string;
}

describe('crm phase 5', () => {
  it('creates, updates and searches customers through CRM routes', async () => {
    const app = createApp();
    const accessToken = await authenticate(app, 'crm@tatuzin.app');

    const createResponse = await request(app)
      .post('/api/customers')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Maria Lima',
        phone: '(11) 99888-7766',
        email: 'maria@tatuzin.app',
        address: 'Rua das Flores, 120',
        notes: 'Cliente recorrente',
      });

    expect(createResponse.status).toBe(201);
    expect(createResponse.body.phone).toBe('11998887766');

    const updateResponse = await request(app)
      .put(`/api/customers/${createResponse.body.id as string}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Maria Lima Silva',
        notes: 'Prefere atendimento via WhatsApp',
      });

    expect(updateResponse.status).toBe(200);
    expect(updateResponse.body.name).toBe('Maria Lima Silva');
    expect(updateResponse.body.notes).toContain('WhatsApp');

    const listResponse = await request(app)
      .get('/api/customers')
      .set('Authorization', `Bearer ${accessToken}`)
      .query({ query: '99888' });

    expect(listResponse.status).toBe(200);
    expect(listResponse.body.items).toHaveLength(1);
    expect(listResponse.body.items[0].name).toBe('Maria Lima Silva');
    expect(listResponse.body.items[0].totalPurchases).toBe(0);
  });

  it('ingests quick customers, sales and receivables into CRM history and summary', async () => {
    const app = createApp();
    const sellerToken = await authenticate(app, 'seller@tatuzin.app');

    const syncResponse = await request(app)
      .post('/api/sync/outbox')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        operations: [
          {
            operationId: 'crm_quick_customer_001',
            type: 'quick_customer',
            entityLocalId: 'customer_local_001',
            payload: {
              localId: 'customer_local_001',
              name: 'Cliente CRM',
              phone: '(11) 97777-6600',
              createdAt: '2026-04-21T10:00:00.000Z',
            },
          },
          {
            operationId: 'crm_sale_001',
            type: 'sale',
            entityLocalId: 'sale_local_001',
            payload: {
              localId: 'sale_local_001',
              customerLocalId: 'customer_local_001',
              subtotalInCents: 18900,
              discountInCents: 900,
              totalInCents: 18000,
              createdAt: '2026-04-21T10:05:00.000Z',
              items: [
                {
                  localId: 'sale_item_local_001',
                  displayName: 'Vestido Midi Terracota',
                  quantity: 1,
                  unitPriceInCents: 18000,
                  totalPriceInCents: 18000,
                },
              ],
              payments: [
                {
                  localId: 'payment_local_001',
                  method: 'note',
                  amountInCents: 18000,
                  dueDate: '2026-05-25T00:00:00.000Z',
                  notes: 'Prazo de 30 dias',
                },
              ],
            },
          },
        ],
      });

    expect(syncResponse.status).toBe(200);
    expect(syncResponse.body.results[0].status).toBe('processed');
    expect(syncResponse.body.results[1].status).toBe('processed');

    const crmToken = await authenticate(app, 'crm@tatuzin.app');

    const customersResponse = await request(app)
      .get('/api/customers')
      .set('Authorization', `Bearer ${crmToken}`)
      .query({ query: '97777' });

    expect(customersResponse.status).toBe(200);
    expect(customersResponse.body.items).toHaveLength(1);

    const customerId = customersResponse.body.items[0].id as string;

    const historyResponse = await request(app)
      .get(`/api/customers/${customerId}/history`)
      .set('Authorization', `Bearer ${crmToken}`);

    expect(historyResponse.status).toBe(200);
    expect(historyResponse.body.customer.name).toBe('Cliente CRM');
    expect(historyResponse.body.purchases).toHaveLength(1);
    expect(historyResponse.body.purchases[0].totalInCents).toBe(18000);
    expect(historyResponse.body.purchases[0].outstandingAmountInCents).toBe(18000);
    expect(historyResponse.body.purchases[0].receivableStatus).toBe('pending');

    const summaryResponse = await request(app)
      .get(`/api/customers/${customerId}/summary`)
      .set('Authorization', `Bearer ${crmToken}`);

    expect(summaryResponse.status).toBe(200);
    expect(summaryResponse.body.totalPurchases).toBe(1);
    expect(summaryResponse.body.totalSpentInCents).toBe(18000);
    expect(summaryResponse.body.averageTicketInCents).toBe(18000);
    expect(summaryResponse.body.totalOutstandingInCents).toBe(18000);
    expect(summaryResponse.body.openReceivablesCount).toBe(1);
    expect(summaryResponse.body.overdueReceivablesCount).toBe(0);
    expect(summaryResponse.body.receivables).toHaveLength(1);
    expect(summaryResponse.body.receivables[0].status).toBe('pending');
  });
});
