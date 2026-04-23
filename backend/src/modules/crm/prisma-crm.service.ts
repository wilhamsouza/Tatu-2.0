import {
  PaymentMethod as PrismaPaymentMethod,
  ReceivableStatus as PrismaReceivableStatus,
  type PrismaClient,
} from '@prisma/client';

import type { CrmServiceContract } from './crm.contract.js';
import {
  CrmServiceError,
  type CreateCustomerInput,
  type CustomerHistoryView,
  type CustomerListItem,
  type CustomerPurchaseHistoryItem,
  type CustomerReceivableListItem,
  type CustomerRecord,
  type CustomerSummaryView,
  type UpdateCustomerInput,
} from './crm.service.js';
import type { ReceivableStatus } from '../sales/receivable-note.js';
import type { SalePaymentMethod } from '../sales/sales.service.js';

type CustomerModel = {
  id: string;
  companyId: string;
  name: string;
  phone: string;
  email: string | null;
  address: string | null;
  notes: string | null;
  source: string;
  createdAt: Date;
  updatedAt: Date;
};

type SaleForCrm = {
  id: string;
  customerId: string | null;
  subtotalInCents: number;
  discountInCents: number;
  totalInCents: number;
  createdAt: Date;
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
  receivableNotes: Array<{
    id: string;
    saleId: string;
    originalAmountInCents: number;
    paidAmountInCents: number;
    outstandingAmountInCents: number;
    dueDate: Date;
    issueDate: Date;
    status: PrismaReceivableStatus;
  }>;
};

type ReceivableForCrm = {
  id: string;
  saleId: string;
  originalAmountInCents: number;
  paidAmountInCents: number;
  outstandingAmountInCents: number;
  dueDate: Date;
  issueDate: Date;
  status: PrismaReceivableStatus;
};

export class PrismaCrmService implements CrmServiceContract {
  constructor(private readonly prisma: PrismaClient) {}

  async listCustomers(
    companyId: string,
    query?: string,
  ): Promise<CustomerListItem[]> {
    const normalizedQuery = query?.trim().toLowerCase();
    const normalizedPhoneQuery = normalizePhone(query ?? '');
    const customers = await this.prisma.customer.findMany({
      where: {
        companyId,
        ...(normalizedQuery == null || normalizedQuery.length === 0
          ? {}
          : {
              OR: [
                { name: { contains: normalizedQuery } },
                { email: { contains: normalizedQuery } },
                ...(normalizedPhoneQuery.length === 0
                  ? []
                  : [{ phone: { contains: normalizedPhoneQuery } }]),
              ],
            }),
      },
      orderBy: { name: 'asc' },
    });

    const items = await Promise.all(
      customers.map((customer) =>
        this.toCustomerListItem(customer as CustomerModel),
      ),
    );

    return items.sort((left, right) => left.name.localeCompare(right.name));
  }

  async createCustomer(input: CreateCustomerInput): Promise<CustomerRecord> {
    await this.ensureCompany(input.companyId);

    const name = normalizeRequired(input.name, 'Customer name is required.');
    const phone = normalizePhoneRequired(input.phone);
    await this.assertPhoneAvailable(input.companyId, phone);

    const customer = await this.prisma.customer.create({
      data: {
        companyId: input.companyId,
        name,
        phone,
        email: normalizeOptional(input.email),
        address: normalizeOptional(input.address),
        notes: normalizeOptional(input.notes),
        source: 'manual',
      },
    });

    return toCustomerRecord(customer);
  }

  async updateCustomer(input: UpdateCustomerInput): Promise<CustomerRecord> {
    const customer = await this.getCustomerModel(input.companyId, input.id);
    const data: {
      name?: string;
      phone?: string;
      email?: string | null;
      address?: string | null;
      notes?: string | null;
    } = {};

    if (input.name != null) {
      data.name = normalizeRequired(input.name, 'Customer name is required.');
    }

    if (input.phone != null) {
      const phone = normalizePhoneRequired(input.phone);
      if (phone !== customer.phone) {
        await this.assertPhoneAvailable(input.companyId, phone, customer.id);
        data.phone = phone;
      }
    }

    if (input.email !== undefined) {
      data.email = normalizeOptional(input.email) ?? null;
    }
    if (input.address !== undefined) {
      data.address = normalizeOptional(input.address) ?? null;
    }
    if (input.notes !== undefined) {
      data.notes = normalizeOptional(input.notes) ?? null;
    }

    const updated = await this.prisma.customer.update({
      where: { id: customer.id },
      data,
    });

    return toCustomerRecord(updated);
  }

  async getCustomer(companyId: string, id: string): Promise<CustomerRecord> {
    return toCustomerRecord(await this.getCustomerModel(companyId, id));
  }

  async getCustomerReceivables(
    companyId: string,
    customerId: string,
  ): Promise<CustomerReceivableListItem[]> {
    await this.getCustomerModel(companyId, customerId);
    const receivables = await this.listReceivables(companyId, customerId);

    return receivables
      .map(toReceivableListItem)
      .sort((left, right) => right.issueDate.localeCompare(left.issueDate));
  }

  async getCustomerHistory(
    companyId: string,
    customerId: string,
  ): Promise<CustomerHistoryView> {
    const customer = await this.getCustomer(companyId, customerId);
    const sales = await this.listSales(companyId, customerId);

    return {
      customer,
      purchases: sales
        .map(toPurchaseHistoryItem)
        .sort((left, right) => right.createdAt.localeCompare(left.createdAt)),
    };
  }

  async getCustomerSummary(
    companyId: string,
    customerId: string,
  ): Promise<CustomerSummaryView> {
    const customer = await this.getCustomer(companyId, customerId);
    const [sales, receivables] = await Promise.all([
      this.listSales(companyId, customerId),
      this.listReceivables(companyId, customerId),
    ]);

    const totalSpentInCents = sales.reduce(
      (accumulator, sale) => accumulator + sale.totalInCents,
      0,
    );
    const totalPurchases = sales.length;
    const lastPurchaseAt = sales
      .map((sale) => sale.createdAt.toISOString())
      .sort()
      .at(-1);

    return {
      customer,
      totalPurchases,
      totalSpentInCents,
      averageTicketInCents:
        totalPurchases === 0
          ? 0
          : Math.round(totalSpentInCents / totalPurchases),
      lastPurchaseAt,
      totalOutstandingInCents: receivables.reduce(
        (accumulator, note) => accumulator + note.outstandingAmountInCents,
        0,
      ),
      openReceivablesCount: receivables.filter(isOpenReceivable).length,
      overdueReceivablesCount: receivables.filter(
        (note) => fromPrismaReceivableStatus(note.status) === 'overdue',
      ).length,
      receivables: receivables
        .map(toReceivableListItem)
        .sort((left, right) => right.issueDate.localeCompare(left.issueDate)),
    };
  }

  async exportSegmentCsv(companyId: string, query?: string): Promise<string> {
    const headers = [
      'id',
      'name',
      'phone',
      'email',
      'totalPurchases',
      'totalSpentInCents',
      'lastPurchaseAt',
      'totalOutstandingInCents',
      'openReceivablesCount',
      'overdueReceivablesCount',
    ];
    const rows = (await this.listCustomers(companyId, query)).map((customer) => [
      customer.id,
      customer.name,
      customer.phone,
      customer.email ?? '',
      `${customer.totalPurchases}`,
      `${customer.totalSpentInCents}`,
      customer.lastPurchaseAt ?? '',
      `${customer.totalOutstandingInCents}`,
      `${customer.openReceivablesCount}`,
      `${customer.overdueReceivablesCount}`,
    ]);

    return [headers, ...rows].map(toCsvRow).join('\n');
  }

  private async toCustomerListItem(
    customer: CustomerModel,
  ): Promise<CustomerListItem> {
    const [sales, receivables] = await Promise.all([
      this.listSales(customer.companyId, customer.id),
      this.listReceivables(customer.companyId, customer.id),
    ]);

    return {
      ...toCustomerRecord(customer),
      totalPurchases: sales.length,
      totalSpentInCents: sales.reduce(
        (accumulator, sale) => accumulator + sale.totalInCents,
        0,
      ),
      lastPurchaseAt: sales
        .map((sale) => sale.createdAt.toISOString())
        .sort()
        .at(-1),
      totalOutstandingInCents: receivables.reduce(
        (accumulator, note) => accumulator + note.outstandingAmountInCents,
        0,
      ),
      openReceivablesCount: receivables.filter(isOpenReceivable).length,
      overdueReceivablesCount: receivables.filter(
        (note) => fromPrismaReceivableStatus(note.status) === 'overdue',
      ).length,
    };
  }

  private async listSales(
    companyId: string,
    customerId: string,
  ): Promise<SaleForCrm[]> {
    const sales = await this.prisma.sale.findMany({
      where: { companyId, customerId },
      include: {
        items: true,
        payments: true,
        receivableNotes: true,
      },
      orderBy: { createdAt: 'asc' },
    });

    return sales as SaleForCrm[];
  }

  private async listReceivables(
    companyId: string,
    customerId: string,
  ): Promise<ReceivableForCrm[]> {
    const receivables = await this.prisma.receivableNote.findMany({
      where: { companyId, customerId },
      orderBy: { issueDate: 'asc' },
    });

    return receivables as ReceivableForCrm[];
  }

  private async getCustomerModel(
    companyId: string,
    id: string,
  ): Promise<CustomerModel> {
    const customer = await this.prisma.customer.findFirst({
      where: { companyId, id },
    });
    if (customer == null) {
      throw new CrmServiceError('Customer not found.');
    }

    return customer as CustomerModel;
  }

  private async assertPhoneAvailable(
    companyId: string,
    phone: string,
    ignoreCustomerId?: string,
  ): Promise<void> {
    const existing = await this.prisma.customer.findUnique({
      where: { companyId_phone: { companyId, phone } },
    });
    if (existing != null && existing.id !== ignoreCustomerId) {
      throw new CrmServiceError('Customer phone already exists.');
    }
  }

  private async ensureCompany(companyId: string): Promise<void> {
    await this.prisma.company.upsert({
      where: { id: companyId },
      create: { id: companyId, name: 'Tatuzin Demo' },
      update: {},
    });
  }
}

function toCustomerRecord(customer: CustomerModel): CustomerRecord {
  return {
    id: customer.id,
    companyId: customer.companyId,
    name: customer.name,
    phone: customer.phone,
    email: customer.email ?? undefined,
    address: customer.address ?? undefined,
    notes: customer.notes ?? undefined,
    createdAt: customer.createdAt.toISOString(),
    updatedAt: customer.updatedAt.toISOString(),
    source: customer.source === 'quick_customer' ? 'quick_customer' : 'manual',
  };
}

function toReceivableListItem(
  note: ReceivableForCrm,
): CustomerReceivableListItem {
  return {
    noteId: note.id,
    saleId: note.saleId,
    originalAmountInCents: note.originalAmountInCents,
    paidAmountInCents: note.paidAmountInCents,
    outstandingAmountInCents: note.outstandingAmountInCents,
    dueDate: note.dueDate.toISOString(),
    issueDate: note.issueDate.toISOString(),
    status: fromPrismaReceivableStatus(note.status),
  };
}

function toPurchaseHistoryItem(sale: SaleForCrm): CustomerPurchaseHistoryItem {
  const receivable = sale.receivableNotes.at(0);

  return {
    saleId: sale.id,
    createdAt: sale.createdAt.toISOString(),
    subtotalInCents: sale.subtotalInCents,
    discountInCents: sale.discountInCents,
    totalInCents: sale.totalInCents,
    itemCount: sale.items.reduce(
      (accumulator, item) => accumulator + item.quantity,
      0,
    ),
    paymentMethods: sale.payments.map((payment) =>
      fromPrismaPaymentMethod(payment.method),
    ),
    items: sale.items.map((item) => ({
      variantId: item.variantId ?? undefined,
      displayName: item.displayName,
      quantity: item.quantity,
      unitPriceInCents: item.unitPriceInCents,
      totalPriceInCents: item.totalPriceInCents,
    })),
    outstandingAmountInCents: receivable?.outstandingAmountInCents ?? 0,
    receivableStatus:
      receivable == null
        ? undefined
        : fromPrismaReceivableStatus(receivable.status),
    receivableDueDate: receivable?.dueDate.toISOString(),
  };
}

function isOpenReceivable(note: ReceivableForCrm): boolean {
  const status = fromPrismaReceivableStatus(note.status);
  return (
    status === 'pending' ||
    status === 'partially_paid' ||
    status === 'overdue'
  );
}

function fromPrismaPaymentMethod(method: PrismaPaymentMethod): SalePaymentMethod {
  switch (method) {
    case PrismaPaymentMethod.PIX:
      return 'pix';
    case PrismaPaymentMethod.NOTE:
      return 'note';
    default:
      return 'cash';
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

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new CrmServiceError(message);
  }
  return normalized;
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
}

function normalizePhoneRequired(value: string): string {
  const normalized = normalizePhone(value);
  if (normalized.length === 0) {
    throw new CrmServiceError('Customer phone is required.');
  }
  return normalized;
}

function normalizePhone(value: string): string {
  return value.replace(/\D/g, '');
}

function toCsvRow(values: string[]): string {
  return values.map(escapeCsvValue).join(',');
}

function escapeCsvValue(value: string): string {
  if (!/[",\n\r]/.test(value)) {
    return value;
  }
  return `"${value.replace(/"/g, '""')}"`;
}
