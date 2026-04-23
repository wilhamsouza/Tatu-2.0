import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from '../src/app.js';

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

describe('erp phase 4', () => {
  it('supports product and variant CRUD and updates inventory after purchase receipt', async () => {
    const { app, accessToken } = await authenticateManager();

    const categoryResponse = await request(app)
      .post('/api/catalog/categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Colecao Inverno',
      });

    expect(categoryResponse.status).toBe(201);
    const categoryId = categoryResponse.body.id as string;

    const productResponse = await request(app)
      .post('/api/catalog/products')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Jaqueta Corta Vento',
        categoryId,
      });

    expect(productResponse.status).toBe(201);
    expect(productResponse.body.categoryName).toBe('Colecao Inverno');
    const productId = productResponse.body.id as string;

    const updatedProductResponse = await request(app)
      .put(`/api/catalog/products/${productId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Jaqueta Corta Vento Premium',
        active: false,
      });

    expect(updatedProductResponse.status).toBe(200);
    expect(updatedProductResponse.body.name).toBe('Jaqueta Corta Vento Premium');
    expect(updatedProductResponse.body.active).toBe(false);

    const variantResponse = await request(app)
      .post('/api/catalog/variants')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        productId,
        barcode: '7890001234567',
        sku: 'JAQ-CV-PREM-G',
        color: 'Preta',
        size: 'G',
        priceInCents: 24990,
      });

    expect(variantResponse.status).toBe(201);
    expect(variantResponse.body.productName).toBe('Jaqueta Corta Vento Premium');
    const variantId = variantResponse.body.id as string;

    const updatedVariantResponse = await request(app)
      .put(`/api/catalog/variants/${variantId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        promotionalPriceInCents: 22990,
        active: true,
      });

    expect(updatedVariantResponse.status).toBe(200);
    expect(updatedVariantResponse.body.promotionalPriceInCents).toBe(22990);

    const productsResponse = await request(app)
      .get('/api/catalog/products')
      .set('Authorization', `Bearer ${accessToken}`);
    const variantsResponse = await request(app)
      .get('/api/catalog/variants')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(productsResponse.status).toBe(200);
    expect(
      productsResponse.body.items.some(
        (product: { id: string }) => product.id === productId,
      ),
    ).toBe(true);
    expect(variantsResponse.status).toBe(200);
    expect(
      variantsResponse.body.items.some(
        (variant: { id: string }) => variant.id === variantId,
      ),
    ).toBe(true);

    const supplierResponse = await request(app)
      .post('/api/suppliers')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        name: 'Fornecedor Norte',
        phone: '11988887777',
      });

    expect(supplierResponse.status).toBe(201);
    const supplierId = supplierResponse.body.id as string;

    const purchaseResponse = await request(app)
      .post('/api/purchases')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        supplierId,
        notes: 'Entrada manual da colecao inverno',
        items: [
          {
            variantId,
            quantityOrdered: 5,
            unitCostInCents: 15000,
          },
        ],
      });

    expect(purchaseResponse.status).toBe(201);
    expect(purchaseResponse.body.status).toBe('pending');
    const purchaseId = purchaseResponse.body.id as string;
    const purchaseItemId = purchaseResponse.body.items[0].id as string;

    const receiveResponse = await request(app)
      .post(`/api/purchases/${purchaseId}/receive`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        items: [
          {
            purchaseItemId,
            quantityReceived: 5,
          },
        ],
      });

    expect(receiveResponse.status).toBe(200);
    expect(receiveResponse.body.status).toBe('received');
    expect(receiveResponse.body.items[0].quantityReceived).toBe(5);

    const inventoryVariantResponse = await request(app)
      .get(`/api/inventory/variants/${variantId}`)
      .set('Authorization', `Bearer ${accessToken}`);

    expect(inventoryVariantResponse.status).toBe(200);
    expect(inventoryVariantResponse.body.quantityOnHand).toBe(5);
    expect(inventoryVariantResponse.body.variantDisplayName).toContain(
      'Jaqueta Corta Vento Premium',
    );

    const inventorySummaryResponse = await request(app)
      .get('/api/inventory/summary')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(inventorySummaryResponse.status).toBe(200);
    expect(
      inventorySummaryResponse.body.items.find(
        (item: { variantId: string }) => item.variantId === variantId,
      )?.quantityOnHand,
    ).toBe(5);

    const adjustmentResponse = await request(app)
      .post('/api/inventory/adjustments')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        variantId,
        quantityDelta: 2,
        reason: 'manual_adjustment_test',
      });

    expect(adjustmentResponse.status).toBe(201);
    expect(adjustmentResponse.body.quantityOnHand).toBe(7);

    const countResponse = await request(app)
      .post('/api/inventory/counts')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        items: [
          {
            variantId,
            countedQuantity: 3,
          },
        ],
      });

    expect(countResponse.status).toBe(201);
    expect(countResponse.body.items[0].quantityOnHand).toBe(3);
  });
});
