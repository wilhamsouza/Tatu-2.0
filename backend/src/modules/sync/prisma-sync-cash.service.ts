import {
  CashMovementType as PrismaCashMovementType,
  CashSessionStatus as PrismaCashSessionStatus,
  type PrismaClient,
} from '@prisma/client';
import { randomUUID } from 'node:crypto';

import type { SyncCashServiceContract } from './sync-cash.contract.js';
import {
  SyncCashServiceError,
  type CloseCashSessionInput,
  type CreateCashMovementInput,
  type OpenCashSessionInput,
  type SyncedCashMovementRecord,
  type SyncedCashSessionSummary,
  type SyncCashMovementType,
} from './sync-cash.service.js';

type CashMovementModel = {
  id: string;
  companyId: string;
  cashSessionLocalId: string;
  userId: string;
  saleLocalId: string | null;
  type: PrismaCashMovementType;
  amountInCents: number;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export class PrismaSyncCashService implements SyncCashServiceContract {
  constructor(private readonly prisma: PrismaClient) {}

  async openSession(
    input: OpenCashSessionInput,
  ): Promise<SyncedCashSessionSummary> {
    const cashSessionLocalId =
      input.cashSessionLocalId ?? randomUUID();
    await this.createMovement({
      companyId: input.companyId,
      userId: input.userId,
      cashSessionLocalId,
      type: 'opening',
      amountInCents: input.openingAmountInCents,
      createdAt: input.openedAt,
    });

    return this.getSession(input.companyId, cashSessionLocalId);
  }

  async closeSession(
    input: CloseCashSessionInput,
  ): Promise<SyncedCashSessionSummary> {
    await this.getSession(input.companyId, input.cashSessionLocalId);
    await this.createMovement({
      companyId: input.companyId,
      userId: input.userId,
      cashSessionLocalId: input.cashSessionLocalId,
      type: 'closing',
      amountInCents: 0,
      notes: input.notes,
      createdAt: input.closedAt,
    });

    return this.getSession(input.companyId, input.cashSessionLocalId);
  }

  async createMovement(
    input: CreateCashMovementInput,
  ): Promise<SyncedCashMovementRecord> {
    if (input.amountInCents < 0) {
      throw new SyncCashServiceError('Cash movement amount cannot be negative.');
    }

    await this.ensureCompany(input.companyId);
    const occurredAt = parseDate(input.createdAt);
    const session = await this.prisma.cashSessionRemote.upsert({
      where: {
        companyId_cashSessionLocalId: {
          companyId: input.companyId,
          cashSessionLocalId: input.cashSessionLocalId,
        },
      },
      create: {
        companyId: input.companyId,
        userId: input.userId,
        cashSessionLocalId: input.cashSessionLocalId,
        status:
          input.type === 'closing'
            ? PrismaCashSessionStatus.CLOSED
            : PrismaCashSessionStatus.OPEN,
        openedAt: occurredAt,
        closedAt: input.type === 'closing' ? occurredAt : undefined,
        notes: input.type === 'closing' ? input.notes : undefined,
      },
      update: {
        ...(input.type === 'closing'
          ? {
              status: PrismaCashSessionStatus.CLOSED,
              closedAt: occurredAt,
              notes: normalizeOptional(input.notes),
            }
          : {}),
      },
    });
    const movement = await this.prisma.cashMovementRemote.create({
      data: {
        companyId: input.companyId,
        cashSessionId: session.id,
        cashSessionLocalId: input.cashSessionLocalId,
        userId: input.userId,
        saleLocalId: normalizeOptional(input.saleLocalId),
        type: toPrismaCashMovementType(input.type),
        amountInCents: input.amountInCents,
        notes: normalizeOptional(input.notes),
        createdAt: occurredAt,
      },
    });

    return toMovementRecord(movement as CashMovementModel);
  }

  async listSessions(companyId: string): Promise<SyncedCashSessionSummary[]> {
    const movements = await this.prisma.cashMovementRemote.findMany({
      where: { companyId },
      orderBy: { createdAt: 'asc' },
    });
    const summaries = new Map<string, SyncedCashSessionSummary>();

    for (const movement of movements as CashMovementModel[]) {
      const record = toMovementRecord(movement);
      const summary =
        summaries.get(record.cashSessionLocalId) ??
        createEmptySessionSummary(record.cashSessionLocalId);
      applyMovementToSummary(summary, record);
      summaries.set(record.cashSessionLocalId, summary);
    }

    return [...summaries.values()].sort((left, right) =>
      (right.openedAt ?? '').localeCompare(left.openedAt ?? ''),
    );
  }

  async listMovementsBySession(
    companyId: string,
    cashSessionLocalId: string,
  ): Promise<SyncedCashMovementRecord[]> {
    const movements = await this.prisma.cashMovementRemote.findMany({
      where: { companyId, cashSessionLocalId },
      orderBy: { createdAt: 'asc' },
    });

    return (movements as CashMovementModel[]).map(toMovementRecord);
  }

  async getSession(
    companyId: string,
    cashSessionLocalId: string,
  ): Promise<SyncedCashSessionSummary> {
    const session = (await this.listSessions(companyId)).find(
      (candidate) => candidate.cashSessionLocalId === cashSessionLocalId,
    );
    if (session == null) {
      throw new SyncCashServiceError('Cash session not found.');
    }

    return session;
  }

  private async ensureCompany(companyId: string): Promise<void> {
    await this.prisma.company.upsert({
      where: { id: companyId },
      create: { id: companyId, name: 'Tatuzin Demo' },
      update: {},
    });
  }
}

function toMovementRecord(
  movement: CashMovementModel,
): SyncedCashMovementRecord {
  return {
    id: movement.id,
    companyId: movement.companyId,
    userId: movement.userId,
    cashSessionLocalId: movement.cashSessionLocalId,
    saleLocalId: movement.saleLocalId ?? undefined,
    type: fromPrismaCashMovementType(movement.type),
    amountInCents: movement.amountInCents,
    notes: movement.notes ?? undefined,
    createdAt: movement.createdAt.toISOString(),
    updatedAt: movement.updatedAt.toISOString(),
  };
}

function applyMovementToSummary(
  summary: SyncedCashSessionSummary,
  movement: SyncedCashMovementRecord,
): void {
  summary.movementCount += 1;
  summary.openedAt =
    summary.openedAt == null || movement.createdAt < summary.openedAt
      ? movement.createdAt
      : summary.openedAt;
  summary.updatedAt =
    summary.updatedAt == null || movement.createdAt > summary.updatedAt
      ? movement.createdAt
      : summary.updatedAt;

  switch (movement.type) {
    case 'opening':
      summary.openingAmountInCents += movement.amountInCents;
      break;
    case 'sale_cash':
      summary.cashSalesInCents += movement.amountInCents;
      break;
    case 'sale_pix':
      summary.pixSalesInCents += movement.amountInCents;
      break;
    case 'sale_note':
      summary.noteSalesInCents += movement.amountInCents;
      break;
    case 'supply':
      summary.suppliesInCents += movement.amountInCents;
      break;
    case 'withdrawal':
      summary.withdrawalsInCents += movement.amountInCents;
      break;
    case 'receivable_settlement_cash':
      summary.receivableSettlementCashInCents += movement.amountInCents;
      break;
    case 'receivable_settlement_pix':
      summary.receivableSettlementPixInCents += movement.amountInCents;
      break;
    case 'closing':
      summary.closedAt = movement.createdAt;
      summary.status = 'closed';
      break;
  }

  summary.expectedCashBalanceInCents =
    summary.openingAmountInCents +
    summary.cashSalesInCents +
    summary.suppliesInCents -
    summary.withdrawalsInCents +
    summary.receivableSettlementCashInCents;
}

function createEmptySessionSummary(
  cashSessionLocalId: string,
): SyncedCashSessionSummary {
  return {
    cashSessionLocalId,
    status: 'open',
    openingAmountInCents: 0,
    cashSalesInCents: 0,
    pixSalesInCents: 0,
    noteSalesInCents: 0,
    suppliesInCents: 0,
    withdrawalsInCents: 0,
    receivableSettlementCashInCents: 0,
    receivableSettlementPixInCents: 0,
    expectedCashBalanceInCents: 0,
    movementCount: 0,
  };
}

function toPrismaCashMovementType(
  type: SyncCashMovementType,
): PrismaCashMovementType {
  switch (type) {
    case 'sale_cash':
      return PrismaCashMovementType.SALE_CASH;
    case 'sale_pix':
      return PrismaCashMovementType.SALE_PIX;
    case 'sale_note':
      return PrismaCashMovementType.SALE_NOTE;
    case 'supply':
      return PrismaCashMovementType.SUPPLY;
    case 'withdrawal':
      return PrismaCashMovementType.WITHDRAWAL;
    case 'receivable_settlement_cash':
      return PrismaCashMovementType.RECEIVABLE_SETTLEMENT_CASH;
    case 'receivable_settlement_pix':
      return PrismaCashMovementType.RECEIVABLE_SETTLEMENT_PIX;
    case 'closing':
      return PrismaCashMovementType.CLOSING;
    default:
      return PrismaCashMovementType.OPENING;
  }
}

function fromPrismaCashMovementType(
  type: PrismaCashMovementType,
): SyncCashMovementType {
  switch (type) {
    case PrismaCashMovementType.SALE_CASH:
      return 'sale_cash';
    case PrismaCashMovementType.SALE_PIX:
      return 'sale_pix';
    case PrismaCashMovementType.SALE_NOTE:
      return 'sale_note';
    case PrismaCashMovementType.SUPPLY:
      return 'supply';
    case PrismaCashMovementType.WITHDRAWAL:
      return 'withdrawal';
    case PrismaCashMovementType.RECEIVABLE_SETTLEMENT_CASH:
      return 'receivable_settlement_cash';
    case PrismaCashMovementType.RECEIVABLE_SETTLEMENT_PIX:
      return 'receivable_settlement_pix';
    case PrismaCashMovementType.CLOSING:
      return 'closing';
    default:
      return 'opening';
  }
}

function parseDate(value?: string): Date {
  return value == null ? new Date() : new Date(value);
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
}
