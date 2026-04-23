import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { PurchasesServiceContract } from './purchases.contract.js';
import { PurchasesServiceError } from './purchases.service.js';

const createSupplierSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    phone: z.string().optional(),
    email: z.string().email().optional(),
    notes: z.string().optional(),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const createPurchaseSchema = z.object({
  body: z.object({
    supplierId: z.string().min(1),
    notes: z.string().optional(),
    items: z
      .array(
        z.object({
          variantId: z.string().min(1),
          quantityOrdered: z.number().int().positive(),
          unitCostInCents: z.number().int().positive(),
        }),
      )
      .min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const receivePurchaseSchema = z.object({
  body: z.object({
    receivedAt: z.string().optional(),
    items: z
      .array(
        z.object({
          purchaseItemId: z.string().min(1),
          quantityReceived: z.number().int().positive(),
        }),
      )
      .min(1),
  }),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

export function createPurchasesRouter(
  purchasesService: PurchasesServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await purchasesService.listPurchases(request.auth!.companyId),
      });
    },
  );

  router.post(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(createPurchaseSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const purchase = await purchasesService.createPurchase({
          companyId: request.auth!.companyId,
          ...request.body,
        });
        response.status(201).json(purchase);
      } catch (error) {
        response
          .status(error instanceof PurchasesServiceError ? 400 : 500)
          .json({
            message: error instanceof Error ? error.message : 'Unexpected error.',
          });
      }
    },
  );

  router.post(
    '/:id/receive',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(receivePurchaseSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const purchase = await purchasesService.receivePurchase({
          companyId: request.auth!.companyId,
          purchaseOrderId: request.params.id as string,
          ...request.body,
        });
        response.status(200).json(purchase);
      } catch (error) {
        response
          .status(error instanceof PurchasesServiceError ? 400 : 500)
          .json({
            message: error instanceof Error ? error.message : 'Unexpected error.',
          });
      }
    },
  );

  router.get(
    '/suppliers',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await purchasesService.listSuppliers(request.auth!.companyId),
      });
    },
  );

  router.post(
    '/suppliers',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(createSupplierSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const supplier = await purchasesService.createSupplier({
          companyId: request.auth!.companyId,
          ...request.body,
        });
        response.status(201).json(supplier);
      } catch (error) {
        response
          .status(error instanceof PurchasesServiceError ? 400 : 500)
          .json({
            message: error instanceof Error ? error.message : 'Unexpected error.',
          });
      }
    },
  );

  return router;
}
