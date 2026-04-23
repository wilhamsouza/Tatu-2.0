import { randomUUID } from 'node:crypto';

export type SyncCashMovementType =
  | 'opening'
  | 'sale_cash'
  | 'sale_pix'
  | 'sale_note'
  | 'supply'
  | 'withdrawal'
  | 'receivable_settlement_cash'
  | 'receivable_settlement_pix'
  | 'closing';

export interface SyncedCashMovementRecord {
  id: string;
  companyId: string;
  userId: string;
  cashSessionLocalId: string;
  saleLocalId?: string;
  type: SyncCashMovementType;
  amountInCents: number;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateCashMovementInput {
  companyId: string;
  userId: string;
  cashSessionLocalId: string;
  saleLocalId?: string;
  type: SyncCashMovementType;
  amountInCents: number;
  notes?: string;
  createdAt?: string;
}

export interface OpenCashSessionInput {
  companyId: string;
  userId: string;
  cashSessionLocalId?: string;
  openingAmountInCents: number;
  openedAt?: string;
}

export interface CloseCashSessionInput {
  companyId: string;
  userId: string;
  cashSessionLocalId: string;
  closedAt?: string;
  notes?: string;
}

export class SyncCashService {
  private readonly movementsById = new Map<string, SyncedCashMovementRecord>();

  openSession(input: OpenCashSessionInput): SyncedCashSessionSummary {
    const cashSessionLocalId = input.cashSessionLocalId ?? randomUUID();
    this.createMovement({
      companyId: input.companyId,
      userId: input.userId,
      cashSessionLocalId,
      type: 'opening',
      amountInCents: input.openingAmountInCents,
      createdAt: input.openedAt,
    });

    return this.getSession(input.companyId, cashSessionLocalId);
  }

  closeSession(input: CloseCashSessionInput): SyncedCashSessionSummary {
    this.ensureSessionExists(input.companyId, input.cashSessionLocalId);
    this.createMovement({
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

  createMovement(input: CreateCashMovementInput): SyncedCashMovementRecord {
    if (input.amountInCents < 0) {
      throw new SyncCashServiceError('Cash movement amount cannot be negative.');
    }

    const now = input.createdAt ?? new Date().toISOString();
    const movement: SyncedCashMovementRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      userId: input.userId,
      cashSessionLocalId: input.cashSessionLocalId,
      saleLocalId: input.saleLocalId,
      type: input.type,
      amountInCents: input.amountInCents,
      notes: input.notes,
      createdAt: now,
      updatedAt: now,
    };

    this.movementsById.set(movement.id, movement);
    return movement;
  }

  listSessions(companyId: string): SyncedCashSessionSummary[] {
    const summaries = new Map<string, SyncedCashSessionSummary>();

    for (const movement of this.movementsById.values()) {
      if (movement.companyId !== companyId) {
        continue;
      }

      const summary =
        summaries.get(movement.cashSessionLocalId) ??
        createEmptySessionSummary(movement.cashSessionLocalId);
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
      summaries.set(movement.cashSessionLocalId, summary);
    }

    return [...summaries.values()].sort((left, right) =>
      (right.openedAt ?? '').localeCompare(left.openedAt ?? ''),
    );
  }

  listMovementsBySession(
    companyId: string,
    cashSessionLocalId: string,
  ): SyncedCashMovementRecord[] {
    return [...this.movementsById.values()]
      .filter(
        (movement) =>
          movement.companyId === companyId &&
          movement.cashSessionLocalId === cashSessionLocalId,
      )
      .sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  }

  getSession(
    companyId: string,
    cashSessionLocalId: string,
  ): SyncedCashSessionSummary {
    const session = this.listSessions(companyId).find(
      (candidate) => candidate.cashSessionLocalId === cashSessionLocalId,
    );
    if (!session) {
      throw new SyncCashServiceError('Cash session not found.');
    }

    return session;
  }

  private ensureSessionExists(
    companyId: string,
    cashSessionLocalId: string,
  ): void {
    this.getSession(companyId, cashSessionLocalId);
  }
}

export class SyncCashServiceError extends Error {}

export interface SyncedCashSessionSummary {
  cashSessionLocalId: string;
  status: 'open' | 'closed';
  openedAt?: string;
  closedAt?: string;
  updatedAt?: string;
  openingAmountInCents: number;
  cashSalesInCents: number;
  pixSalesInCents: number;
  noteSalesInCents: number;
  suppliesInCents: number;
  withdrawalsInCents: number;
  receivableSettlementCashInCents: number;
  receivableSettlementPixInCents: number;
  expectedCashBalanceInCents: number;
  movementCount: number;
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
