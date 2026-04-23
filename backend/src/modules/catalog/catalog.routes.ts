import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { CatalogServiceContract } from './catalog.contract.js';
import { CatalogServiceError } from './catalog.service.js';

const categoryBodySchema = z.object({
  name: z.string().min(1),
  active: z.boolean().optional(),
});

const productBodySchema = z.object({
  name: z.string().min(1),
  categoryId: z.string().optional(),
  active: z.boolean().optional(),
});

const productUpdateBodySchema = z.object({
  name: z.string().min(1).optional(),
  categoryId: z.string().nullable().optional(),
  active: z.boolean().optional(),
});

const variantBodySchema = z.object({
  productId: z.string().min(1),
  barcode: z.string().optional(),
  sku: z.string().optional(),
  color: z.string().optional(),
  size: z.string().optional(),
  priceInCents: z.number().int().positive(),
  promotionalPriceInCents: z.number().int().positive().optional(),
  active: z.boolean().optional(),
});

const variantUpdateBodySchema = z.object({
  barcode: z.string().nullable().optional(),
  sku: z.string().nullable().optional(),
  color: z.string().nullable().optional(),
  size: z.string().nullable().optional(),
  priceInCents: z.number().int().positive().optional(),
  promotionalPriceInCents: z.number().int().positive().nullable().optional(),
  active: z.boolean().optional(),
});

const createCategorySchema = z.object({
  body: categoryBodySchema,
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const updateCategorySchema = z.object({
  body: categoryBodySchema.partial(),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

const createProductSchema = z.object({
  body: productBodySchema,
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const updateProductSchema = z.object({
  body: productUpdateBodySchema,
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

const createVariantSchema = z.object({
  body: variantBodySchema,
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const updateVariantSchema = z.object({
  body: variantUpdateBodySchema,
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

export function createCatalogRouter(
  catalogService: CatalogServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/categories',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await catalogService.listCategories(request.auth!.companyId),
      });
    },
  );

  router.post(
    '/categories',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(createCategorySchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const category = await catalogService.createCategory({
          companyId: request.auth!.companyId,
          ...request.body,
        });
        response.status(201).json(category);
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.put(
    '/categories/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(updateCategorySchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const category = await catalogService.updateCategory({
          companyId: request.auth!.companyId,
          id: request.params.id as string,
          ...request.body,
        });
        response.status(200).json(category);
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/products',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await catalogService.listProducts(request.auth!.companyId),
      });
    },
  );

  router.post(
    '/products',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(createProductSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const product = await catalogService.createProduct({
          companyId: request.auth!.companyId,
          ...request.body,
        });
        response.status(201).json(product);
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.put(
    '/products/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(updateProductSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const product = await catalogService.updateProduct({
          companyId: request.auth!.companyId,
          id: request.params.id as string,
          ...request.body,
        });
        response.status(200).json(product);
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/variants',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await catalogService.listVariants(request.auth!.companyId),
      });
    },
  );

  router.post(
    '/variants',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(createVariantSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const variant = await catalogService.createVariant({
          companyId: request.auth!.companyId,
          ...request.body,
        });
        response.status(201).json(variant);
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.put(
    '/variants/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager'),
    validateRequest(updateVariantSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const variant = await catalogService.updateVariant({
          companyId: request.auth!.companyId,
          id: request.params.id as string,
          ...request.body,
        });
        response.status(200).json(variant);
      } catch (error) {
        response.status(error instanceof CatalogServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/sale-snapshots',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier'),
    async (request: AuthenticatedRequest, response) => {
      response
        .status(200)
        .json(await catalogService.buildSaleSnapshots(request.auth!.companyId));
    },
  );

  return router;
}
