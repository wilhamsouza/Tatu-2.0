import { Router } from "express";
import { z } from "zod";

import { authenticate } from "../../core/auth/auth.middleware.js";
import { JwtService } from "../../core/auth/jwt.service.js";
import type { AuthenticatedRequest } from "../../core/auth/request-context.js";
import { requireRoles } from "../../core/permissions/role.middleware.js";
import { requireTenancy } from "../../core/tenancy/tenancy.middleware.js";
import { validateRequest } from "../../core/validation/validate-request.js";
import type { SyncCashServiceContract } from "../sync/sync-cash.contract.js";

const sessionDetailsSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

const openSessionSchema = z.object({
  body: z.object({
    cashSessionLocalId: z.string().min(1).optional(),
    openingAmountInCents: z.number().int().min(0),
    openedAt: z.string().optional(),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const closeSessionSchema = z.object({
  body: z.object({
    closedAt: z.string().optional(),
    notes: z.string().optional(),
  }).optional().default({}),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

const movementSchema = z.object({
  body: z.object({
    cashSessionLocalId: z.string().min(1),
    saleLocalId: z.string().optional(),
    type: z.enum([
      "supply",
      "withdrawal",
      "sale_cash",
      "sale_pix",
      "sale_note",
      "receivable_settlement_cash",
      "receivable_settlement_pix",
    ]),
    amountInCents: z.number().int().min(0),
    notes: z.string().optional(),
    createdAt: z.string().optional(),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

export function createCashRouter(
  cashService: SyncCashServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.post(
    "/sessions/open",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(openSessionSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(201).json(
          await cashService.openSession({
            companyId: request.auth!.companyId,
            userId: request.auth!.userId,
            cashSessionLocalId: request.body.cashSessionLocalId,
            openingAmountInCents: request.body.openingAmountInCents,
            openedAt: request.body.openedAt,
          }),
        );
      } catch (error) {
        response.status(error instanceof Error ? 400 : 500).json({
          message: error instanceof Error ? error.message : "Unexpected error.",
        });
      }
    },
  );

  router.get(
    "/sessions",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        items: await cashService.listSessions(request.auth!.companyId),
      });
    },
  );

  router.get(
    "/sessions/:id",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(sessionDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        cashSessionLocalId: request.params.id,
        movements: await cashService.listMovementsBySession(
          request.auth!.companyId,
          request.params.id as string,
        ),
      });
    },
  );

  router.post(
    "/sessions/:id/close",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(closeSessionSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(200).json(
          await cashService.closeSession({
            companyId: request.auth!.companyId,
            userId: request.auth!.userId,
            cashSessionLocalId: request.params.id as string,
            closedAt: request.body.closedAt,
            notes: request.body.notes,
          }),
        );
      } catch (error) {
        response.status(error instanceof Error ? 404 : 500).json({
          message: error instanceof Error ? error.message : "Unexpected error.",
        });
      }
    },
  );

  router.post(
    "/movements",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(movementSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        response.status(201).json(
          await cashService.createMovement({
            companyId: request.auth!.companyId,
            userId: request.auth!.userId,
            cashSessionLocalId: request.body.cashSessionLocalId,
            saleLocalId: request.body.saleLocalId,
            type: request.body.type,
            amountInCents: request.body.amountInCents,
            notes: request.body.notes,
            createdAt: request.body.createdAt,
          }),
        );
      } catch (error) {
        response.status(error instanceof Error ? 400 : 500).json({
          message: error instanceof Error ? error.message : "Unexpected error.",
        });
      }
    },
  );

  return router;
}
