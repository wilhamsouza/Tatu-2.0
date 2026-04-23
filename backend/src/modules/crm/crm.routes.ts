import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { CrmServiceContract } from './crm.contract.js';
import { CrmServiceError } from './crm.service.js';

const customerBodySchema = z.object({
  name: z.string().min(1),
  phone: z.string().min(1),
  email: z.string().email().optional(),
  address: z.string().optional(),
  notes: z.string().optional(),
});

const customerUpdateBodySchema = z.object({
  name: z.string().min(1).optional(),
  phone: z.string().min(1).optional(),
  email: z.string().email().nullable().optional(),
  address: z.string().nullable().optional(),
  notes: z.string().nullable().optional(),
});

const listCustomersSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({}).optional().default({}),
  query: z.object({
    query: z.string().optional(),
  }),
});

const exportSegmentSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({}).optional().default({}),
  query: z.object({
    format: z.enum(['csv']).optional().default('csv'),
    query: z.string().optional(),
  }),
});

const createCustomerSchema = z.object({
  body: customerBodySchema,
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const updateCustomerSchema = z.object({
  body: customerUpdateBodySchema,
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

const customerDetailsSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

export function createCrmRouter(
  crmService: CrmServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(listCustomersSchema),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await crmService.listCustomers(
          request.auth!.companyId,
          request.query.query as string | undefined,
        ),
      });
    },
  );

  router.post(
    '/',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(createCustomerSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const customer = await crmService.createCustomer({
          companyId: request.auth!.companyId,
          ...request.body,
        });
        response.status(201).json(customer);
      } catch (error) {
        response.status(error instanceof CrmServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.put(
    '/:id',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(updateCustomerSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const customer = await crmService.updateCustomer({
          companyId: request.auth!.companyId,
          id: request.params.id as string,
          ...request.body,
        });
        response.status(200).json(customer);
      } catch (error) {
        response.status(error instanceof CrmServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/:id/receivables',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(customerDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json({
          items: await crmService.getCustomerReceivables(
            request.auth!.companyId,
            request.params.id as string,
          ),
        });
      } catch (error) {
        response.status(error instanceof CrmServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/:id/history',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(customerDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await crmService.getCustomerHistory(
            request.auth!.companyId,
            request.params.id as string,
          ),
        );
      } catch (error) {
        response.status(error instanceof CrmServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.get(
    '/:id/summary',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(customerDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await crmService.getCustomerSummary(
            request.auth!.companyId,
            request.params.id as string,
          ),
        );
      } catch (error) {
        response.status(error instanceof CrmServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  return router;
}

export function createCrmAdminRouter(
  crmService: CrmServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/segments/export',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'crm_user'),
    validateRequest(exportSegmentSchema),
    async (request: AuthenticatedRequest, response) => {
      const csv = await crmService.exportSegmentCsv(
        request.auth!.companyId,
        request.query.query as string | undefined,
      );
      response
        .status(200)
        .setHeader('content-type', 'text/csv; charset=utf-8')
        .setHeader(
          'content-disposition',
          'attachment; filename="tatuzin-crm-segment.csv"',
        )
        .send(csv);
    },
  );

  return router;
}
