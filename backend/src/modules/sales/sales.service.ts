import { randomUUID } from 'node:crypto';

import type { ReceivableNote } from './receivable-note.js';
import { ReceivableService } from './receivable.service.js';

export type SalePaymentMethod = 'cash' | 'pix' | 'note';

export interface SaleItemInput {
  variantId?: string;
  displayName: string;
  quantity: number;
  unitPriceInCents: number;
  totalPriceInCents: number;
}

export interface SalePaymentInput {
  method: SalePaymentMethod;
  amountInCents: number;
  dueDate?: string;
  notes?: string;
}

export interface CreateSaleInput {
  operationId?: string;
  companyId: string;
  userId: string;
  customerId?: string;
  subtotalInCents: number;
  discountInCents: number;
  totalInCents: number;
  items: SaleItemInput[];
  payments: SalePaymentInput[];
  createdAt?: string;
}

export interface SaleRecord {
  id: string;
  operationId?: string;
  companyId: string;
  userId: string;
  customerId?: string;
  status: 'completed' | 'canceled';
  subtotalInCents: number;
  discountInCents: number;
  totalInCents: number;
  items: SaleItemInput[];
  payments: SalePaymentInput[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateSaleResult {
  sale: SaleRecord;
  receivableNotes: ReceivableNote[];
  duplicated: boolean;
}

export class SalesService {
  constructor(private readonly receivableService: ReceivableService) {}

  private readonly salesById = new Map<string, SaleRecord>();
  private readonly salesByOperationId = new Map<string, CreateSaleResult>();

  createSale(input: CreateSaleInput): CreateSaleResult {
    if (input.operationId) {
      const existing = this.salesByOperationId.get(input.operationId);
      if (existing) {
        return {
          ...existing,
          duplicated: true,
        };
      }
    }

    if (input.items.length === 0) {
      throw new SalesServiceError('Sale must have at least one item.');
    }

    if (input.payments.length === 0) {
      throw new SalesServiceError('Sale must have at least one payment.');
    }

    const notePayments = input.payments.filter((payment) => payment.method === 'note');
    if (notePayments.length > 0 && !input.customerId) {
      throw new SalesServiceError(
        'Note payment requires an identified customer in the current policy.',
      );
    }

    for (const payment of notePayments) {
      if (!payment.dueDate) {
        throw new SalesServiceError('Note payment requires dueDate.');
      }
    }

    const now = input.createdAt ?? new Date().toISOString();
    const sale: SaleRecord = {
      id: randomUUID(),
      operationId: input.operationId,
      companyId: input.companyId,
      userId: input.userId,
      customerId: input.customerId,
      status: 'completed',
      subtotalInCents: input.subtotalInCents,
      discountInCents: input.discountInCents,
      totalInCents: input.totalInCents,
      items: input.items,
      payments: input.payments,
      createdAt: now,
      updatedAt: now,
    };

    const receivableNotes = notePayments.map((payment) =>
      this.receivableService.issueFromSale({
        companyId: input.companyId,
        saleId: sale.id,
        customerId: input.customerId,
        originalAmountInCents: payment.amountInCents,
        dueDate: payment.dueDate!,
        issueDate: now,
        notes: payment.notes,
        createdByUserId: input.userId,
      }).note,
    );

    this.salesById.set(sale.id, sale);
    const result: CreateSaleResult = {
      sale,
      receivableNotes,
      duplicated: false,
    };

    if (input.operationId) {
      this.salesByOperationId.set(input.operationId, result);
    }

    return result;
  }

  listSales(companyId: string): SaleRecord[] {
    return [...this.salesById.values()]
      .filter((sale) => sale.companyId === companyId)
      .map((sale) => ({
        ...sale,
        items: sale.items.map((item) => ({ ...item })),
        payments: sale.payments.map((payment) => ({ ...payment })),
      }))
      .sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  }

  listSalesByCustomer(companyId: string, customerId: string): SaleRecord[] {
    return this.listSales(companyId).filter((sale) => sale.customerId === customerId);
  }

  getSale(companyId: string, saleId: string): SaleRecord {
    const sale = this.salesById.get(saleId);
    if (!sale || sale.companyId !== companyId) {
      throw new SalesServiceError('Sale not found.');
    }

    return {
      ...sale,
      items: sale.items.map((item) => ({ ...item })),
      payments: sale.payments.map((payment) => ({ ...payment })),
    };
  }

  cancelSale(companyId: string, saleId: string): SaleRecord {
    const sale = this.salesById.get(saleId);
    if (!sale || sale.companyId !== companyId) {
      throw new SalesServiceError('Sale not found.');
    }
    if (sale.status === 'canceled') {
      return this.getSale(companyId, saleId);
    }

    const updated: SaleRecord = {
      ...sale,
      status: 'canceled',
      updatedAt: new Date().toISOString(),
    };
    this.salesById.set(saleId, updated);
    return this.getSale(companyId, saleId);
  }
}

export class SalesServiceError extends Error {}
