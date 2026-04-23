import {
  PaymentMethod as PrismaPaymentMethod,
  SaleStatus as PrismaSaleStatus,
  type PrismaClient,
} from '@prisma/client';

import { seedDemoIdentity } from '../auth/prisma-identity.seed.js';
import type { ReceivableServiceContract } from './receivable.contract.js';
import type { ReceivableNote } from './receivable-note.js';
import type { SalesServiceContract } from './sales.contract.js';
import {
  SalesServiceError,
  type CreateSaleInput,
  type CreateSaleResult,
  type SalePaymentInput,
  type SalePaymentMethod,
  type SaleRecord,
} from './sales.service.js';

type SaleWithRelations = {
  id: string;
  operationId: string | null;
  companyId: string;
  userId: string;
  customerId: string | null;
  status: PrismaSaleStatus;
  subtotalInCents: number;
  discountInCents: number;
  totalInCents: number;
  createdAt: Date;
  updatedAt: Date;
  items: Array<{
    variantId: string | null;
    displayName: string;
    quantity: number;
    unitPriceInCents: number;
    totalPriceInCents: number;
  }>;
  payments: Array<{
    method: PrismaPaymentMethod;
    amountInCents: number;
    dueDate: Date | null;
    notes: string | null;
  }>;
};

export class PrismaSalesService implements SalesServiceContract {
  private seedPromise?: Promise<void>;

  constructor(
    private readonly prisma: PrismaClient,
    private readonly receivableService: ReceivableServiceContract,
  ) {}

  async createSale(input: CreateSaleInput): Promise<CreateSaleResult> {
    await this.ensureSeeded();

    if (input.operationId != null) {
      const existing = await this.findByOperationId(
        input.companyId,
        input.operationId,
      );
      if (existing != null) {
        return this.toCreateSaleResult(existing, true);
      }
    }

    await this.validateSaleInput(input);
    const createdAt = input.createdAt ?? new Date().toISOString();
    const sale = await this.prisma.sale.create({
      data: {
        operationId: input.operationId,
        companyId: input.companyId,
        userId: input.userId,
        customerId: input.customerId,
        status: PrismaSaleStatus.COMPLETED,
        subtotalInCents: input.subtotalInCents,
        discountInCents: input.discountInCents,
        totalInCents: input.totalInCents,
        createdAt: new Date(createdAt),
        items: {
          create: input.items.map((item) => ({
            variantId: item.variantId,
            displayName: item.displayName,
            quantity: item.quantity,
            unitPriceInCents: item.unitPriceInCents,
            totalPriceInCents: item.totalPriceInCents,
          })),
        },
        payments: {
          create: input.payments.map((payment) => ({
            method: toPrismaPaymentMethod(payment.method),
            amountInCents: payment.amountInCents,
            dueDate:
              payment.dueDate == null ? undefined : new Date(payment.dueDate),
            notes: normalizeOptional(payment.notes),
          })),
        },
      },
      include: { items: true, payments: true },
    });

    const receivableNotes: ReceivableNote[] = [];
    for (const payment of input.payments.filter(
      (candidate) => candidate.method === 'note',
    )) {
      const result = await this.receivableService.issueFromSale({
        companyId: input.companyId,
        saleId: sale.id,
        customerId: input.customerId,
        originalAmountInCents: payment.amountInCents,
        dueDate: payment.dueDate!,
        issueDate: createdAt,
        notes: payment.notes,
        createdByUserId: input.userId,
      });
      receivableNotes.push(result.note);
    }

    return {
      sale: toSaleRecord(sale as SaleWithRelations),
      receivableNotes,
      duplicated: false,
    };
  }

  async listSales(companyId: string): Promise<SaleRecord[]> {
    await this.ensureSeeded();
    const sales = await this.prisma.sale.findMany({
      where: { companyId },
      include: { items: true, payments: true },
      orderBy: { createdAt: 'asc' },
    });

    return sales.map((sale) => toSaleRecord(sale as SaleWithRelations));
  }

  async listSalesByCustomer(
    companyId: string,
    customerId: string,
  ): Promise<SaleRecord[]> {
    await this.ensureSeeded();
    const sales = await this.prisma.sale.findMany({
      where: { companyId, customerId },
      include: { items: true, payments: true },
      orderBy: { createdAt: 'asc' },
    });

    return sales.map((sale) => toSaleRecord(sale as SaleWithRelations));
  }

  async getSale(companyId: string, saleId: string): Promise<SaleRecord> {
    await this.ensureSeeded();
    const sale = await this.prisma.sale.findFirst({
      where: { companyId, id: saleId },
      include: { items: true, payments: true },
    });

    if (sale == null) {
      throw new SalesServiceError('Sale not found.');
    }

    return toSaleRecord(sale as SaleWithRelations);
  }

  async cancelSale(companyId: string, saleId: string): Promise<SaleRecord> {
    await this.ensureSeeded();
    const sale = await this.prisma.sale.findFirst({
      where: { companyId, id: saleId },
    });

    if (sale == null) {
      throw new SalesServiceError('Sale not found.');
    }
    if (sale.status === PrismaSaleStatus.CANCELED) {
      return this.getSale(companyId, saleId);
    }

    const updated = await this.prisma.sale.update({
      where: { id: sale.id },
      data: { status: PrismaSaleStatus.CANCELED },
      include: { items: true, payments: true },
    });

    return toSaleRecord(updated as SaleWithRelations);
  }

  private async toCreateSaleResult(
    sale: SaleWithRelations,
    duplicated: boolean,
  ): Promise<CreateSaleResult> {
    const note = await this.receivableService.findBySale(
      sale.companyId,
      sale.id,
    );

    return {
      sale: toSaleRecord(sale),
      receivableNotes: note == null ? [] : [note],
      duplicated,
    };
  }

  private async findByOperationId(
    companyId: string,
    operationId: string,
  ): Promise<SaleWithRelations | undefined> {
    const sale = await this.prisma.sale.findFirst({
      where: { companyId, operationId },
      include: { items: true, payments: true },
    });

    return sale == null ? undefined : (sale as SaleWithRelations);
  }

  private async validateSaleInput(input: CreateSaleInput): Promise<void> {
    if (input.items.length === 0) {
      throw new SalesServiceError('Sale must have at least one item.');
    }
    if (input.payments.length === 0) {
      throw new SalesServiceError('Sale must have at least one payment.');
    }

    const notePayments = input.payments.filter(
      (payment) => payment.method === 'note',
    );
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

    await this.assertUserExists(input.userId);
    if (input.customerId != null) {
      await this.assertCustomerExists(input.companyId, input.customerId);
    }
    for (const item of input.items) {
      if (item.variantId != null) {
        await this.assertVariantExists(input.companyId, item.variantId);
      }
    }
  }

  private async assertUserExists(userId: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user == null) {
      throw new SalesServiceError('User not found.');
    }
  }

  private async assertCustomerExists(
    companyId: string,
    customerId: string,
  ): Promise<void> {
    const customer = await this.prisma.customer.findFirst({
      where: { companyId, id: customerId },
    });
    if (customer == null) {
      throw new SalesServiceError('Customer not found.');
    }
  }

  private async assertVariantExists(
    companyId: string,
    variantId: string,
  ): Promise<void> {
    const variant = await this.prisma.productVariant.findFirst({
      where: { companyId, id: variantId },
    });
    if (variant == null) {
      throw new SalesServiceError('Variant not found.');
    }
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= seedDemoIdentity(this.prisma);
    return this.seedPromise;
  }
}

function toSaleRecord(sale: SaleWithRelations): SaleRecord {
  return {
    id: sale.id,
    operationId: sale.operationId ?? undefined,
    companyId: sale.companyId,
    userId: sale.userId,
    customerId: sale.customerId ?? undefined,
    status:
      sale.status === PrismaSaleStatus.CANCELED ? 'canceled' : 'completed',
    subtotalInCents: sale.subtotalInCents,
    discountInCents: sale.discountInCents,
    totalInCents: sale.totalInCents,
    items: sale.items.map((item) => ({
      variantId: item.variantId ?? undefined,
      displayName: item.displayName,
      quantity: item.quantity,
      unitPriceInCents: item.unitPriceInCents,
      totalPriceInCents: item.totalPriceInCents,
    })),
    payments: sale.payments.map(toSalePaymentInput),
    createdAt: sale.createdAt.toISOString(),
    updatedAt: sale.updatedAt.toISOString(),
  };
}

function toSalePaymentInput(payment: {
  method: PrismaPaymentMethod;
  amountInCents: number;
  dueDate: Date | null;
  notes: string | null;
}): SalePaymentInput {
  return {
    method: fromPrismaPaymentMethod(payment.method),
    amountInCents: payment.amountInCents,
    dueDate: payment.dueDate?.toISOString(),
    notes: payment.notes ?? undefined,
  };
}

function toPrismaPaymentMethod(method: SalePaymentMethod): PrismaPaymentMethod {
  switch (method) {
    case 'pix':
      return PrismaPaymentMethod.PIX;
    case 'note':
      return PrismaPaymentMethod.NOTE;
    default:
      return PrismaPaymentMethod.CASH;
  }
}

function fromPrismaPaymentMethod(
  method: PrismaPaymentMethod,
): SalePaymentMethod {
  switch (method) {
    case PrismaPaymentMethod.PIX:
      return 'pix';
    case PrismaPaymentMethod.NOTE:
      return 'note';
    default:
      return 'cash';
  }
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
}
