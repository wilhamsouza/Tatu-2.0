import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from '../src/app.js';

describe('auth module', () => {
  it('logs in and returns company context with roles', async () => {
    const app = createApp();

    const response = await request(app).post('/api/auth/login').send({
      email: 'admin@tatuzin.app',
      password: 'tatuzin123',
    });

    expect(response.status).toBe(200);
    expect(response.body.user.companyId).toBe('company_tatuzin');
    expect(response.body.user.roles).toContain('admin');
    expect(response.body.tokens.accessToken).toBeTypeOf('string');
    expect(response.body.tokens.refreshToken).toBeTypeOf('string');
    expect(response.body.tokens.expiresAt).toBeTypeOf('string');
  });

  it('blocks protected routes without a bearer token', async () => {
    const app = createApp();

    const response = await request(app).get('/api/auth/me');

    expect(response.status).toBe(401);
  });

  it('serves company context and admin user management routes', async () => {
    const app = createApp();
    const adminLogin = await request(app).post('/api/auth/login').send({
      email: 'admin@tatuzin.app',
      password: 'tatuzin123',
    });
    const sellerLogin = await request(app).post('/api/auth/login').send({
      email: 'seller@tatuzin.app',
      password: 'tatuzin123',
    });
    const adminToken = adminLogin.body.tokens.accessToken as string;
    const sellerToken = sellerLogin.body.tokens.accessToken as string;

    const companyResponse = await request(app)
      .get('/api/companies/current')
      .set('Authorization', `Bearer ${adminToken}`);
    const usersResponse = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${adminToken}`);
    const forbiddenUsersResponse = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${sellerToken}`);
    const createdUserResponse = await request(app)
      .post('/api/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Usuario Teste',
        email: 'usuario.teste@tatuzin.app',
        password: 'tatuzin123',
        roles: ['seller', 'cashier'],
      });
    const updatedUserResponse = await request(app)
      .put(`/api/users/${createdUserResponse.body.id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Usuario Teste Atualizado',
        roles: ['manager'],
      });
    const updatedCompanyResponse = await request(app)
      .put('/api/companies/current')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Tatuzin Moda Atualizada' });

    expect(companyResponse.status).toBe(200);
    expect(companyResponse.body).toMatchObject({
      id: 'company_tatuzin',
      name: 'Tatuzin Moda',
    });
    expect(usersResponse.status).toBe(200);
    expect(usersResponse.body.items.length).toBeGreaterThanOrEqual(5);
    expect(forbiddenUsersResponse.status).toBe(403);
    expect(createdUserResponse.status).toBe(201);
    expect(createdUserResponse.body.roles).toEqual(['seller', 'cashier']);
    expect(updatedUserResponse.status).toBe(200);
    expect(updatedUserResponse.body).toMatchObject({
      name: 'Usuario Teste Atualizado',
      roles: ['manager'],
    });
    expect(updatedCompanyResponse.status).toBe(200);
    expect(updatedCompanyResponse.body.name).toBe('Tatuzin Moda Atualizada');
  });
});
