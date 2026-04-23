import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import { SyncService } from './sync.service.js';

const outboxSchema = z.object({
  body: z.object({
    operations: z.array(
      z.object({
        operationId: z.string().min(1),
        type: z.enum([
          'sale',
          'cash_movement',
          'quick_customer',
          'receivable_note',
          'receivable_settlement',
        ]),
        entityLocalId: z.string().min(1),
        payload: z.record(z.unknown()),
      }),
    ),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const updatesSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({}).optional().default({}),
  query: z.object({
    cursor: z.string().min(1).optional(),
    limit: z.coerce.number().int().min(1).max(100).optional().default(50),
  }),
});

export function createSyncRouter(
  syncService: SyncService,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.post(
    '/outbox',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier'),
    validateRequest(outboxSchema),
    async (request: AuthenticatedRequest, response) => {
      const results = await syncService.ingestOutbox(
        request.body.operations,
        request.auth!,
      );

      response.status(200).json({
        results,
      });
    },
  );

  router.get(
    '/updates',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier'),
    validateRequest(updatesSchema),
    (request: AuthenticatedRequest, response) => {
      const result = syncService.pullUpdates({
        cursor: request.query.cursor as string | undefined,
        limit: Number(request.query.limit ?? 50),
        auth: request.auth!,
      });

      response.status(200).json(result);
    },
  );

  router.get(
    '/status',
    authenticate(jwtService),
    requireTenancy,
    (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        companyId: request.auth!.companyId,
        status: 'ok',
        supportedOutboxTypes: [
          'sale',
          'cash_movement',
          'quick_customer',
          'receivable_note',
          'receivable_settlement',
        ],
        supportedUpdateTypes: [
          'category_snapshot',
          'product_snapshot',
          'variant_snapshot',
          'price_snapshot',
        ],
      });
    },
  );

  return router;
}
