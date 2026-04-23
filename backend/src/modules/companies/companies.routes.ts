import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { CompanyServiceContract } from './company.contract.js';
import { CompanyServiceError } from './company.service.js';

const updateCompanySchema = z.object({
  body: z.object({
    name: z.string().min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

export function createCompaniesRouter(
  companyService: CompanyServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    '/current',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier', 'crm_user'),
    async (request: AuthenticatedRequest, response) => {
      try {
        response
          .status(200)
          .json(await companyService.getCurrent(request.auth!.companyId));
      } catch (error) {
        response.status(error instanceof CompanyServiceError ? 404 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  router.put(
    '/current',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin'),
    validateRequest(updateCompanySchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await companyService.updateCurrent({
            companyId: request.auth!.companyId,
            name: request.body.name,
          }),
        );
      } catch (error) {
        response.status(error instanceof CompanyServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : 'Unexpected error.',
        });
      }
    },
  );

  return router;
}
