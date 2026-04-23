import { randomUUID } from 'node:crypto';

export type ReceivableStatus =
  | 'pending'
  | 'partially_paid'
  | 'paid'
  | 'overdue'
  | 'canceled';

export type SettlementMethod = 'cash' | 'pix' | 'bank_transfer' | 'mixed';

export interface ReceivableNote {
  id: string;
  companyId: string;
  saleId: string;
  customerId?: string;
  originalAmountInCents: number;
  paidAmountInCents: number;
  outstandingAmountInCents: number;
  dueDate: string;
  issueDate: string;
  status: ReceivableStatus;
  notes?: string;
  createdByUserId: string;
  createdAt: string;
  updatedAt: string;
}

export interface ReceivableSettlement {
  id: string;
  receivableNoteId: string;
  amountInCents: number;
  settlementMethod: SettlementMethod;
  settledAt: string;
  createdByUserId: string;
  createdAt: string;
}

interface CreateReceivableNoteInput {
  companyId: string;
  saleId: string;
  customerId?: string;
  originalAmountInCents: number;
  dueDate: string;
  issueDate?: string;
  notes?: string;
  createdByUserId: string;
}

interface CreateSettlementInput {
  note: ReceivableNote;
  amountInCents: number;
  settlementMethod: SettlementMethod;
  settledAt: string;
  createdByUserId: string;
}

export function createReceivableNote(
  input: CreateReceivableNoteInput,
): ReceivableNote {
  if (input.originalAmountInCents <= 0) {
    throw new ReceivableNoteError('Original amount must be greater than zero.');
  }

  const issueDate = input.issueDate ?? new Date().toISOString();
  const status = resolveReceivableStatus({
    dueDate: input.dueDate,
    outstandingAmountInCents: input.originalAmountInCents,
    paidAmountInCents: 0,
    now: issueDate,
  });

  return {
    id: randomUUID(),
    companyId: input.companyId,
    saleId: input.saleId,
    customerId: input.customerId,
    originalAmountInCents: input.originalAmountInCents,
    paidAmountInCents: 0,
    outstandingAmountInCents: input.originalAmountInCents,
    dueDate: input.dueDate,
    issueDate,
    status,
    notes: input.notes,
    createdByUserId: input.createdByUserId,
    createdAt: issueDate,
    updatedAt: issueDate,
  };
}

export function applyReceivableSettlement(
  input: CreateSettlementInput,
): { note: ReceivableNote; settlement: ReceivableSettlement } {
  if (input.amountInCents <= 0) {
    throw new ReceivableNoteError('Settlement amount must be greater than zero.');
  }

  if (input.amountInCents > input.note.outstandingAmountInCents) {
    throw new ReceivableNoteError('Settlement amount exceeds outstanding balance.');
  }

  const paidAmountInCents = input.note.paidAmountInCents + input.amountInCents;
  const outstandingAmountInCents = Math.max(
    input.note.originalAmountInCents - paidAmountInCents,
    0,
  );

  const note: ReceivableNote = {
    ...input.note,
    paidAmountInCents,
    outstandingAmountInCents,
    status: resolveReceivableStatus({
      dueDate: input.note.dueDate,
      outstandingAmountInCents,
      paidAmountInCents,
      now: input.settledAt,
    }),
    updatedAt: input.settledAt,
  };

  return {
    note,
    settlement: {
      id: randomUUID(),
      receivableNoteId: input.note.id,
      amountInCents: input.amountInCents,
      settlementMethod: input.settlementMethod,
      settledAt: input.settledAt,
      createdByUserId: input.createdByUserId,
      createdAt: new Date().toISOString(),
    },
  };
}

export function resolveReceivableStatus(input: {
  dueDate: string;
  outstandingAmountInCents: number;
  paidAmountInCents: number;
  now: string;
}): ReceivableStatus {
  if (input.outstandingAmountInCents <= 0) {
    return 'paid';
  }

  const dueDate = dateOnly(input.dueDate);
  const today = dateOnly(input.now);
  if (dueDate < today) {
    return 'overdue';
  }

  if (input.paidAmountInCents > 0) {
    return 'partially_paid';
  }

  return 'pending';
}

function dateOnly(value: string): number {
  const parsed = new Date(value);
  return Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate());
}

export class ReceivableNoteError extends Error {}
