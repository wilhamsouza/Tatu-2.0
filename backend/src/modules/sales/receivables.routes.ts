import { Router } from "express";
import { z } from "zod";

import { authenticate } from "../../core/auth/auth.middleware.js";
import { JwtService } from "../../core/auth/jwt.service.js";
import type { AuthenticatedRequest } from "../../core/auth/request-context.js";
import { requireRoles } from "../../core/permissions/role.middleware.js";
import { requireTenancy } from "../../core/tenancy/tenancy.middleware.js";
import { validateRequest } from "../../core/validation/validate-request.js";
import type { ReceivableServiceContract } from "./receivable.contract.js";
import {
  ReceivableServiceError,
} from "./receivable.service.js";

const listReceivablesSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({}).optional().default({}),
  query: z.object({
    customerId: z.string().optional(),
    status: z
      .enum(["pending", "partially_paid", "paid", "overdue", "canceled"])
      .optional(),
  }),
});

const receivableDetailsSchema = z.object({
  body: z.object({}).optional().default({}),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

const createSettlementSchema = z.object({
  body: z.object({
    operationId: z.string().optional(),
    amountInCents: z.number().int().positive(),
    settlementMethod: z.enum(["cash", "pix", "bank_transfer", "mixed"]),
    settledAt: z.string().optional(),
  }),
  params: z.object({ id: z.string().min(1) }),
  query: z.object({}).optional().default({}),
});

export function createReceivablesRouter(
  receivableService: ReceivableServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.get(
    "/",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(listReceivablesSchema),
    async (request: AuthenticatedRequest, response) => {
      const customerId = request.query.customerId as string | undefined;
      const status = request.query.status as string | undefined;
      const notes =
        customerId == null
          ? await receivableService.listNotes(request.auth!.companyId)
          : await receivableService.listNotesByCustomer(
              request.auth!.companyId,
              customerId,
            );

      response.status(200).json({
        items:
          status == null
            ? notes
            : notes.filter((note) => note.status === status),
      });
    },
  );

  router.get(
    "/:id",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(receivableDetailsSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const note = await receivableService.getNote(
          request.auth!.companyId,
          request.params.id as string,
        );
        response.status(200).json({
          note,
          settlements: await receivableService.listSettlements(note.id),
        });
      } catch (error) {
        response
          .status(error instanceof ReceivableServiceError ? 404 : 500)
          .json({
            message:
              error instanceof Error ? error.message : "Unexpected error.",
          });
      }
    },
  );

  router.post(
    "/:id/settlements",
    authenticate(jwtService),
    requireTenancy,
    requireRoles("admin", "manager", "cashier"),
    validateRequest(createSettlementSchema),
    async (request: AuthenticatedRequest, response) => {
      try {
        const result = await receivableService.registerSettlement({
          companyId: request.auth!.companyId,
          noteId: request.params.id as string,
          operationId: request.body.operationId,
          amountInCents: request.body.amountInCents,
          settlementMethod: request.body.settlementMethod,
          settledAt: request.body.settledAt,
          createdByUserId: request.auth!.userId,
        });
        response.status(result.duplicated ? 200 : 201).json(result);
      } catch (error) {
        response
          .status(error instanceof ReceivableServiceError ? 400 : 500)
          .json({
            message:
              error instanceof Error ? error.message : "Unexpected error.",
          });
      }
    },
  );

  return router;
}
