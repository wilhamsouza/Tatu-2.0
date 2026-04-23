import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { UsersServiceContract } from './users.contract.js';
import { UsersServiceError } from './users.service.js';

const roleSchema = z.enum([
  'admin',
  'manager',
  'seller',
  'cashier',
  'crm_user',
]);

const createUserSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    email: z.string().email(),
    password: z.string().min(6),
    roles: z.array(roleSchema).min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const updateUserSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    email: z.string().email().optional(),
    password: z.string().min(6).optional(),
    roles: z.array(roleSchema).min(1).optional(),
  }),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

export function createUsersRouter(
  usersService: UsersServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await usersService.listUsers(request.auth!.companyId),
      });
    },
  );

  router.post(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin'),
    validateRequest(createUserSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(201).json(
          await usersService.createUser({
            companyId: request.auth!.companyId,
            companyName: request.auth!.companyName,
            ...request.body,
          }),
        );
      } catch (error) {
        response.status(error instanceof UsersServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.put(
    '/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin'),
    validateRequest(updateUserSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await usersService.updateUser({
            companyId: request.auth!.companyId,
            id: request.params.id as string,
            ...request.body,
          }),
        );
      } catch (error) {
        response.status(error instanceof UsersServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  return router;
}
