import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { CatalogServiceContract } from '../catalog/catalog.contract.js';
import { CatalogServiceError } from '../catalog/catalog.service.js';
import type { InventoryServiceContract } from './inventory.contract.js';

const adjustmentSchema = z.object({
  body: z.object({
    variantId: z.string().min(1),
    quantityDelta: z.number().int(),
    reason: z.string().optional(),
    createdAt: z.string().optional(),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const countSchema = z.object({
  body: z.object({
    createdAt: z.string().optional(),
    items: z
      .array(
        z.object({
          variantId: z.string().min(1),
          countedQuantity: z.number().int().min(0),
        }),
      )
      .min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

export function createInventoryRouter(
  catalogService: CatalogServiceContract,
  inventoryService: InventoryServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/summary',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      const companyId = request.auth!.companyId;
      const variants = await catalogService.listVariants(companyId);
      response.status(200).json({
        items: await inventoryService.listSummary(companyId, variants),
      });
    },
  );

  router.get(
    '/variants/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      try {
        const companyId = request.auth!.companyId;
        const variant = await catalogService.getVariant(
          companyId,
          request.params.id as string,
        );
        response.status(200).json(
          await inventoryService.getInventorySummaryItem(companyId, variant),
        );
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.post(
    '/adjustments',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(adjustmentSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const companyId = request.auth!.companyId;
        await catalogService.getVariant(companyId, request.body.variantId);
        response.status(201).json(
          await inventoryService.createAdjustment({
            companyId,
            variantId: request.body.variantId,
            quantityDelta: request.body.quantityDelta,
            reason: request.body.reason,
            createdAt: request.body.createdAt,
          }),
        );
      } catch (error) {
        response
          .status(
            error instanceof CatalogServiceError ||
              error instanceof Error
              ? 400
              : 500,
          )
          .json({
            message: error instanceof Error ? error.message : 'Unexpected error.',
          });
      }
    },
  );

  router.post(
    '/counts',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(countSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const companyId = request.auth!.companyId;
        for (const item of request.body.items) {
          await catalogService.getVariant(companyId, item.variantId);
        }
        response.status(201).json({
          items: await inventoryService.recordCount({
            companyId,
            items: request.body.items,
            createdAt: request.body.createdAt,
          }),
        });
      } catch (error) {
        response.status(error instanceof Error ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  return router;
}
