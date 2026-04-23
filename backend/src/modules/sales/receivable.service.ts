import type {
  ReceivableNote,
  ReceivableSettlement,
  SettlementMethod,
} from "./receivable-note.js";
import {
  applyReceivableSettlement,
  createReceivableNote,
  ReceivableNoteError,
} from "./receivable-note.js";

export interface IssueReceivableNoteInput {
  companyId: string;
  saleId: string;
  customerId?: string;
  originalAmountInCents: number;
  dueDate: string;
  issueDate?: string;
  notes?: string;
  createdByUserId: string;
}

export interface IssueReceivableNoteResult {
  note: ReceivableNote;
  duplicated: boolean;
}

export interface RegisterReceivableSettlementInput {
  companyId: string;
  noteId: string;
  operationId?: string;
  amountInCents: number;
  settlementMethod: SettlementMethod;
  settledAt?: string;
  createdByUserId: string;
}

export interface RegisterReceivableSettlementResult {
  note: ReceivableNote;
  settlement: ReceivableSettlement;
  duplicated: boolean;
}

export class ReceivableService {
  private readonly notesById = new Map<string, ReceivableNote>();
  private readonly noteIdBySaleKey = new Map<string, string>();
  private readonly settlementsById = new Map<string, ReceivableSettlement>();
  private readonly settlementIdByOperationKey = new Map<string, string>();

  issueFromSale(input: IssueReceivableNoteInput): IssueReceivableNoteResult {
    const saleKey = this.toSaleKey(input.companyId, input.saleId);
    const existingId = this.noteIdBySaleKey.get(saleKey);
    if (existingId) {
      return {
        note: this.notesById.get(existingId)!,
        duplicated: true,
      };
    }

    const note = createReceivableNote({
      companyId: input.companyId,
      saleId: input.saleId,
      customerId: input.customerId,
      originalAmountInCents: input.originalAmountInCents,
      dueDate: input.dueDate,
      issueDate: input.issueDate,
      notes: input.notes,
      createdByUserId: input.createdByUserId,
    });

    this.notesById.set(note.id, note);
    this.noteIdBySaleKey.set(saleKey, note.id);

    return {
      note,
      duplicated: false,
    };
  }

  findBySale(companyId: string, saleId: string): ReceivableNote | undefined {
    const noteId = this.noteIdBySaleKey.get(this.toSaleKey(companyId, saleId));
    return noteId == null ? undefined : this.notesById.get(noteId);
  }

  listNotes(companyId: string): ReceivableNote[] {
    return [...this.notesById.values()]
      .filter((note) => note.companyId === companyId)
      .map((note) => ({ ...note }))
      .sort((left, right) => left.issueDate.localeCompare(right.issueDate));
  }

  listNotesByCustomer(companyId: string, customerId: string): ReceivableNote[] {
    return this.listNotes(companyId).filter(
      (note) => note.customerId === customerId,
    );
  }

  getNote(companyId: string, noteId: string): ReceivableNote {
    const note = this.notesById.get(noteId);
    if (!note || note.companyId !== companyId) {
      throw new ReceivableServiceError("Receivable note not found.");
    }

    return { ...note };
  }

  listSettlements(noteId: string): ReceivableSettlement[] {
    return [...this.settlementsById.values()]
      .filter((settlement) => settlement.receivableNoteId === noteId)
      .map((settlement) => ({ ...settlement }))
      .sort((left, right) => left.settledAt.localeCompare(right.settledAt));
  }

  registerSettlement(
    input: RegisterReceivableSettlementInput,
  ): RegisterReceivableSettlementResult {
    const operationKey =
      input.operationId == null
        ? undefined
        : this.toOperationKey(input.companyId, input.operationId);
    const existingSettlementId =
      operationKey == null
        ? undefined
        : this.settlementIdByOperationKey.get(operationKey);

    if (existingSettlementId) {
      const settlement = this.settlementsById.get(existingSettlementId)!;
      return {
        note: this.getNote(input.companyId, settlement.receivableNoteId),
        settlement: { ...settlement },
        duplicated: true,
      };
    }

    const note = this.getNote(input.companyId, input.noteId);
    const settledAt = input.settledAt ?? new Date().toISOString();

    try {
      const result = applyReceivableSettlement({
        note,
        amountInCents: input.amountInCents,
        settlementMethod: input.settlementMethod,
        settledAt,
        createdByUserId: input.createdByUserId,
      });

      this.notesById.set(result.note.id, result.note);
      this.settlementsById.set(result.settlement.id, result.settlement);
      if (operationKey != null) {
        this.settlementIdByOperationKey.set(operationKey, result.settlement.id);
      }

      return {
        note: { ...result.note },
        settlement: { ...result.settlement },
        duplicated: false,
      };
    } catch (error) {
      if (error instanceof ReceivableNoteError) {
        throw new ReceivableServiceError(error.message);
      }
      throw error;
    }
  }

  private toSaleKey(companyId: string, saleId: string): string {
    return `${companyId}:${saleId}`;
  }

  private toOperationKey(companyId: string, operationId: string): string {
    return `${companyId}:${operationId}`;
  }
}

export class ReceivableServiceError extends Error {}
