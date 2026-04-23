import {
  ReceivableStatus as PrismaReceivableStatus,
  SettlementMethod as PrismaSettlementMethod,
  type Prisma,
  type PrismaClient,
} from '@prisma/client';

import type { ReceivableServiceContract } from './receivable.contract.js';
import {
  applyReceivableSettlement,
  createReceivableNote,
  type ReceivableNote,
  type ReceivableSettlement,
  type ReceivableStatus,
  type SettlementMethod,
} from './receivable-note.js';
import {
  ReceivableServiceError,
  type IssueReceivableNoteInput,
  type IssueReceivableNoteResult,
  type RegisterReceivableSettlementInput,
  type RegisterReceivableSettlementResult,
} from './receivable.service.js';

type ReceivableDatabase = PrismaClient | Prisma.TransactionClient;

type ReceivableNoteModel = {
  id: string;
  companyId: string;
  saleId: string;
  customerId: string | null;
  originalAmountInCents: number;
  paidAmountInCents: number;
  outstandingAmountInCents: number;
  dueDate: Date;
  issueDate: Date;
  status: PrismaReceivableStatus;
  notes: string | null;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
};

type ReceivableSettlementModel = {
  id: string;
  receivableNoteId: string;
  amountInCents: number;
  settlementMethod: PrismaSettlementMethod;
  settledAt: Date;
  createdByUserId: string;
  createdAt: Date;
};

export class PrismaReceivableService implements ReceivableServiceContract {
  constructor(private readonly prisma: PrismaClient) {}

  async issueFromSale(
    input: IssueReceivableNoteInput,
  ): Promise<IssueReceivableNoteResult> {
    const existing = await this.prisma.receivableNote.findUnique({
      where: { companyId_saleId: { companyId: input.companyId, saleId: input.saleId } },
    });

    if (existing != null) {
      return {
        note: toReceivableNote(existing),
        duplicated: true,
      };
    }

    const note = createReceivableNote(input);
    const created = await this.prisma.receivableNote.create({
      data: {
        id: note.id,
        companyId: note.companyId,
        saleId: note.saleId,
        customerId: note.customerId,
        originalAmountInCents: note.originalAmountInCents,
        paidAmountInCents: note.paidAmountInCents,
        outstandingAmountInCents: note.outstandingAmountInCents,
        dueDate: new Date(note.dueDate),
        issueDate: new Date(note.issueDate),
        status: toPrismaReceivableStatus(note.status),
        notes: note.notes,
        createdByUserId: note.createdByUserId,
        createdAt: new Date(note.createdAt),
      },
    });

    return {
      note: toReceivableNote(created),
      duplicated: false,
    };
  }

  async findBySale(
    companyId: string,
    saleId: string,
  ): Promise<ReceivableNote | undefined> {
    const note = await this.prisma.receivableNote.findUnique({
      where: { companyId_saleId: { companyId, saleId } },
    });

    return note == null ? undefined : toReceivableNote(note);
  }

  async listNotes(companyId: string): Promise<ReceivableNote[]> {
    const notes = await this.prisma.receivableNote.findMany({
      where: { companyId },
      orderBy: { issueDate: 'asc' },
    });

    return notes.map(toReceivableNote);
  }

  async listNotesByCustomer(
    companyId: string,
    customerId: string,
  ): Promise<ReceivableNote[]> {
    const notes = await this.prisma.receivableNote.findMany({
      where: { companyId, customerId },
      orderBy: { issueDate: 'asc' },
    });

    return notes.map(toReceivableNote);
  }

  async getNote(
    companyId: string,
    noteId: string,
  ): Promise<ReceivableNote> {
    const note = await this.prisma.receivableNote.findFirst({
      where: { companyId, id: noteId },
    });

    if (note == null) {
      throw new ReceivableServiceError('Receivable note not found.');
    }

    return toReceivableNote(note);
  }

  async listSettlements(noteId: string): Promise<ReceivableSettlement[]> {
    const settlements = await this.prisma.receivableSettlement.findMany({
      where: { receivableNoteId: noteId },
      orderBy: { settledAt: 'asc' },
    });

    return settlements.map(toReceivableSettlement);
  }

  async registerSettlement(
    input: RegisterReceivableSettlementInput,
  ): Promise<RegisterReceivableSettlementResult> {
    return this.prisma.$transaction((tx) =>
      this.registerSettlementWithClient(tx, input),
    );
  }

  async registerSettlementWithClient(
    db: ReceivableDatabase,
    input: RegisterReceivableSettlementInput,
  ): Promise<RegisterReceivableSettlementResult> {
    const existing =
      input.operationId == null
        ? undefined
        : await db.receivableSettlement.findFirst({
            where: {
              operationId: input.operationId,
              receivableNote: { companyId: input.companyId },
            },
          });

    if (existing != null) {
      return {
        note: await this.getNoteWithClient(
          db,
          input.companyId,
          existing.receivableNoteId,
        ),
        settlement: toReceivableSettlement(existing),
        duplicated: true,
      };
    }

    const note = await this.getNoteWithClient(db, input.companyId, input.noteId);

    try {
      const result = applyReceivableSettlement({
        note,
        amountInCents: input.amountInCents,
        settlementMethod: input.settlementMethod,
        settledAt: input.settledAt ?? new Date().toISOString(),
        createdByUserId: input.createdByUserId,
      });

      const [updatedNote, createdSettlement] = await Promise.all([
        db.receivableNote.update({
          where: { id: note.id },
          data: {
            paidAmountInCents: result.note.paidAmountInCents,
            outstandingAmountInCents: result.note.outstandingAmountInCents,
            status: toPrismaReceivableStatus(result.note.status),
            updatedAt: new Date(result.note.updatedAt),
          },
        }),
        db.receivableSettlement.create({
          data: {
            id: result.settlement.id,
            receivableNoteId: note.id,
            operationId: input.operationId,
            amountInCents: result.settlement.amountInCents,
            settlementMethod: toPrismaSettlementMethod(
              result.settlement.settlementMethod,
            ),
            settledAt: new Date(result.settlement.settledAt),
            createdByUserId: result.settlement.createdByUserId,
            createdAt: new Date(result.settlement.createdAt),
          },
        }),
      ]);

      return {
        note: toReceivableNote(updatedNote),
        settlement: toReceivableSettlement(createdSettlement),
        duplicated: false,
      };
    } catch (error) {
      throw new ReceivableServiceError(
        error instanceof Error ? error.message : 'Unexpected receivable error.',
      );
    }
  }

  private async getNoteWithClient(
    db: ReceivableDatabase,
    companyId: string,
    noteId: string,
  ): Promise<ReceivableNote> {
    const note = await db.receivableNote.findFirst({
      where: { companyId, id: noteId },
    });

    if (note == null) {
      throw new ReceivableServiceError('Receivable note not found.');
    }

    return toReceivableNote(note);
  }
}

function toReceivableNote(note: ReceivableNoteModel): ReceivableNote {
  return {
    id: note.id,
    companyId: note.companyId,
    saleId: note.saleId,
    customerId: note.customerId ?? undefined,
    originalAmountInCents: note.originalAmountInCents,
    paidAmountInCents: note.paidAmountInCents,
    outstandingAmountInCents: note.outstandingAmountInCents,
    dueDate: note.dueDate.toISOString(),
    issueDate: note.issueDate.toISOString(),
    status: fromPrismaReceivableStatus(note.status),
    notes: note.notes ?? undefined,
    createdByUserId: note.createdByUserId,
    createdAt: note.createdAt.toISOString(),
    updatedAt: note.updatedAt.toISOString(),
  };
}

function toReceivableSettlement(
  settlement: ReceivableSettlementModel,
): ReceivableSettlement {
  return {
    id: settlement.id,
    receivableNoteId: settlement.receivableNoteId,
    amountInCents: settlement.amountInCents,
    settlementMethod: fromPrismaSettlementMethod(settlement.settlementMethod),
    settledAt: settlement.settledAt.toISOString(),
    createdByUserId: settlement.createdByUserId,
    createdAt: settlement.createdAt.toISOString(),
  };
}

function toPrismaReceivableStatus(
  status: ReceivableStatus,
): PrismaReceivableStatus {
  switch (status) {
    case 'partially_paid':
      return PrismaReceivableStatus.PARTIALLY_PAID;
    case 'paid':
      return PrismaReceivableStatus.PAID;
    case 'overdue':
      return PrismaReceivableStatus.OVERDUE;
    case 'canceled':
      return PrismaReceivableStatus.CANCELED;
    default:
      return PrismaReceivableStatus.PENDING;
  }
}

function fromPrismaReceivableStatus(
  status: PrismaReceivableStatus,
): ReceivableStatus {
  switch (status) {
    case PrismaReceivableStatus.PARTIALLY_PAID:
      return 'partially_paid';
    case PrismaReceivableStatus.PAID:
      return 'paid';
    case PrismaReceivableStatus.OVERDUE:
      return 'overdue';
    case PrismaReceivableStatus.CANCELED:
      return 'canceled';
    default:
      return 'pending';
  }
}

function toPrismaSettlementMethod(
  method: SettlementMethod,
): PrismaSettlementMethod {
  switch (method) {
    case 'pix':
      return PrismaSettlementMethod.PIX;
    case 'bank_transfer':
      return PrismaSettlementMethod.BANK_TRANSFER;
    case 'mixed':
      return PrismaSettlementMethod.MIXED;
    default:
      return PrismaSettlementMethod.CASH;
  }
}

function fromPrismaSettlementMethod(
  method: PrismaSettlementMethod,
): SettlementMethod {
  switch (method) {
    case PrismaSettlementMethod.PIX:
      return 'pix';
    case PrismaSettlementMethod.BANK_TRANSFER:
      return 'bank_transfer';
    case PrismaSettlementMethod.MIXED:
      return 'mixed';
    default:
      return 'cash';
  }
}
