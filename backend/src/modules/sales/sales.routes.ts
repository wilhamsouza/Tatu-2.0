import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { SalesServiceContract } from './sales.contract.js';
import { SalesServiceError } from './sales.service.js';

const createSaleSchema = z.object({
  body: z.object({
    operationId: z.string().optional(),
    customerId: z.string().optional(),
    subtotalInCents: z.number().int().positive(),
    discountInCents: z.number().int().min(0),
    totalInCents: z.number().int().positive(),
    createdAt: z.string().optional(),
    items: z
      .array(
        z.object({
          variantId: z.string().optional(),
          displayName: z.string().min(1),
          quantity: z.number().int().positive(),
          unitPriceInCents: z.number().int().positive(),
          totalPriceInCents: z.number().int().positive(),
        }),
      )
      .min(1),
    payments: z
      .array(
        z.object({
          method: z.enum(['cash', 'pix', 'note']),
          amountInCents: z.number().int().positive(),
          dueDate: z.string().optional(),
          notes: z.string().optional(),
        }),
      )
      .min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const saleDetailsSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

export function createSalesRouter(
  salesService: SalesServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.post(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier'),
    validateRequest(createSaleSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const auth = request.auth!;
        const result = await salesService.createSale({
          ...request.body,
          companyId: auth.companyId,
          userId: auth.userId,
        });
        response.status(result.duplicated ? 200 : 201).json(result);
      } catch (error) {
        response.status(error instanceof SalesServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await salesService.listSales(request.auth!.companyId),
      });
    },
  );

  router.get(
    '/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier'),
    validateRequest(saleDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await salesService.getSale(
            request.auth!.companyId,
            request.params.id as string,
          ),
        );
      } catch (error) {
        response.status(error instanceof SalesServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.post(
    '/:id/cancel',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(saleDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await salesService.cancelSale(
            request.auth!.companyId,
            request.params.id as string,
          ),
        );
      } catch (error) {
        response.status(error instanceof SalesServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  return router;
}
