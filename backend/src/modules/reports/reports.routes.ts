import { Router } from "express";
import { z } from "zod";

import { authenticate } from "../../core/auth/auth.middleware.js";
import { JwtService } from "../../core/auth/jwt.service.js";
import type { AuthenticatedRequest } from "../../core/auth/request-context.js";
import { requireRoles } from "../../core/permissions/role.middleware.js";
import { requireTenancy } from "../../core/tenancy/tenancy.middleware.js";
import { validateRequest } from "../../core/validation/validate-request.js";
import type { ReportsServiceContract } from "./reports.contract.js";
import { ReportsServiceError } from "./reports.service.js";

const dashboardSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({}).optional().default({}),
  query: z.object({
    referenceDate: z.string().optional(),
    rankingLimit: z.coerce.number().int().min(1).max(10).optional().default(5),
  }),
});

export function createReportsRouter(
  reportsService: ReportsServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    "/dashboard",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager"),
    validateRequest(dashboardSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await reportsService.buildDashboard({
            companyId: request.auth!.companyId,
            referenceDate: request.query.referenceDate as string | undefined,
            rankingLimit: Number(request.query.rankingLimit ?? 5),
          }),
        );
      } catch (error) {
        response.status(error instanceof ReportsServiceError ? 400 : 500).json({
          message: error instanceof Error ? error.message : "Unexpected error.",
        });
      }
    },
  );

  return router;
}
