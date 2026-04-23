import { randomUUID } from 'node:crypto';

import type { ReceivableNote, ReceivableStatus } from '../sales/receivable-note.js';
import { ReceivableService } from '../sales/receivable.service.js';
import type { SaleItemInput, SalePaymentMethod, SaleRecord } from '../sales/sales.service.js';
import { SalesService } from '../sales/sales.service.js';

export interface CustomerRecord {
  id: string;
  companyId: string;
  name: string;
  phone: string;
  email?: string;
  address?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  source: 'manual' | 'quick_customer';
}

export interface CustomerListItem extends CustomerRecord {
  totalPurchases: number;
  totalSpentInCents: number;
  lastPurchaseAt?: string;
  totalOutstandingInCents: number;
  openReceivablesCount: number;
  overdueReceivablesCount: number;
}

export interface CustomerReceivableListItem {
  noteId: string;
  saleId: string;
  originalAmountInCents: number;
  paidAmountInCents: number;
  outstandingAmountInCents: number;
  dueDate: string;
  issueDate: string;
  status: ReceivableStatus;
}

export interface CustomerSummaryView {
  customer: CustomerRecord;
  totalPurchases: number;
  totalSpentInCents: number;
  averageTicketInCents: number;
  lastPurchaseAt?: string;
  totalOutstandingInCents: number;
  openReceivablesCount: number;
  overdueReceivablesCount: number;
  receivables: CustomerReceivableListItem[];
}

export interface CustomerPurchaseHistoryItem {
  saleId: string;
  createdAt: string;
  subtotalInCents: number;
  discountInCents: number;
  totalInCents: number;
  itemCount: number;
  paymentMethods: SalePaymentMethod[];
  items: SaleItemInput[];
  outstandingAmountInCents: number;
  receivableStatus?: ReceivableStatus;
  receivableDueDate?: string;
}

export interface CustomerHistoryView {
  customer: CustomerRecord;
  purchases: CustomerPurchaseHistoryItem[];
}

export interface CreateCustomerInput {
  companyId: string;
  name: string;
  phone: string;
  email?: string;
  address?: string;
  notes?: string;
}

export interface UpdateCustomerInput {
  companyId: string;
  id: string;
  name?: string;
  phone?: string;
  email?: string | null;
  address?: string | null;
  notes?: string | null;
}

interface UpsertQuickCustomerInput {
  companyId: string;
  localId: string;
  name: string;
  phone: string;
  createdAt?: string;
}

export interface UpsertQuickCustomerResult {
  customer: CustomerRecord;
  duplicated: boolean;
}

export class CrmService {
  private readonly customersById = new Map<string, CustomerRecord>();
  private readonly customerIdByLocalKey = new Map<string, string>();
  private readonly customerIdByPhoneKey = new Map<string, string>();

  constructor(
    private readonly salesService: SalesService,
    private readonly receivableService: ReceivableService,
  ) {}

  listCustomers(companyId: string, query?: string): CustomerListItem[] {
    const normalizedQuery = query?.trim().toLowerCase();
    const normalizedPhoneQuery = normalizePhone(query ?? '');

    return [...this.customersById.values()]
      .filter((customer) => customer.companyId === companyId)
      .filter((customer) => {
        if (!normalizedQuery) {
          return true;
        }

        const matchesName = customer.name.toLowerCase().includes(normalizedQuery);
        const matchesEmail = customer.email?.toLowerCase().includes(normalizedQuery) ?? false;
        const matchesPhone =
          normalizedPhoneQuery.length > 0 &&
          customer.phone.includes(normalizedPhoneQuery);

        return matchesName || matchesEmail || matchesPhone;
      })
      .map((customer) => this.toCustomerListItem(customer))
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  createCustomer(input: CreateCustomerInput): CustomerRecord {
    const name = normalizeRequired(input.name, 'Customer name is required.');
    const phone = normalizePhoneRequired(input.phone);
    this.assertPhoneAvailable(input.companyId, phone);

    const now = new Date().toISOString();
    const customer: CustomerRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      name,
      phone,
      email: normalizeOptional(input.email),
      address: normalizeOptional(input.address),
      notes: normalizeOptional(input.notes),
      createdAt: now,
      updatedAt: now,
      source: 'manual',
    };

    this.customersById.set(customer.id, customer);
    this.customerIdByPhoneKey.set(this.toPhoneKey(input.companyId, phone), customer.id);
    return customer;
  }

  updateCustomer(input: UpdateCustomerInput): CustomerRecord {
    const customer = this.getCustomer(input.companyId, input.id);

    if (input.name != null) {
      customer.name = normalizeRequired(input.name, 'Customer name is required.');
    }

    if (input.phone != null) {
      const normalizedPhone = normalizePhoneRequired(input.phone);
      if (normalizedPhone !== customer.phone) {
        this.assertPhoneAvailable(input.companyId, normalizedPhone, customer.id);
        this.customerIdByPhoneKey.delete(this.toPhoneKey(input.companyId, customer.phone));
        customer.phone = normalizedPhone;
        this.customerIdByPhoneKey.set(
          this.toPhoneKey(input.companyId, normalizedPhone),
          customer.id,
        );
      }
    }

    if (input.email !== undefined) {
      customer.email = normalizeOptional(input.email);
    }
    if (input.address !== undefined) {
      customer.address = normalizeOptional(input.address);
    }
    if (input.notes !== undefined) {
      customer.notes = normalizeOptional(input.notes);
    }

    customer.updatedAt = new Date().toISOString();
    this.customersById.set(customer.id, customer);
    return customer;
  }

  getCustomer(companyId: string, id: string): CustomerRecord {
    const customer = this.customersById.get(id);
    if (!customer || customer.companyId !== companyId) {
      throw new CrmServiceError('Customer not found.');
    }
    return { ...customer };
  }

  getCustomerHistory(companyId: string, customerId: string): CustomerHistoryView {
    const customer = this.getCustomer(companyId, customerId);
    const purchases = this.salesService
      .listSalesByCustomer(companyId, customer.id)
      .map((sale) => this.toPurchaseHistoryItem(companyId, sale))
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

    return {
      customer,
      purchases,
    };
  }

  getCustomerSummary(companyId: string, customerId: string): CustomerSummaryView {
    const customer = this.getCustomer(companyId, customerId);
    const sales = this.salesService.listSalesByCustomer(companyId, customer.id);
    const receivables = this.receivableService.listNotesByCustomer(companyId, customer.id);
    const totalSpentInCents = sales.reduce(
      (accumulator, sale) => accumulator + sale.totalInCents,
      0,
    );
    const totalPurchases = sales.length;
    const lastPurchaseAt = sales
      .map((sale) => sale.createdAt)
      .sort()
      .at(-1);
    const totalOutstandingInCents = receivables.reduce(
      (accumulator, note) => accumulator + note.outstandingAmountInCents,
      0,
    );
    const openReceivablesCount = receivables.filter((note) =>
      note.status === 'pending' || note.status === 'partially_paid',
    ).length;
    const overdueReceivablesCount = receivables.filter(
      (note) => note.status === 'overdue',
    ).length;

    return {
      customer,
      totalPurchases,
      totalSpentInCents,
      averageTicketInCents:
        totalPurchases == 0 ? 0 : Math.round(totalSpentInCents / totalPurchases),
      lastPurchaseAt,
      totalOutstandingInCents,
      openReceivablesCount,
      overdueReceivablesCount,
      receivables: receivables
        .map((note) => this.toReceivableListItem(note))
        .sort((left, right) => right.issueDate.localeCompare(left.issueDate)),
    };
  }

  exportSegmentCsv(companyId: string, query?: string): string {
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
    const rows = this.listCustomers(companyId, query).map((customer) => [
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

  getCustomerReceivables(
    companyId: string,
    customerId: string,
  ): CustomerReceivableListItem[] {
    this.getCustomer(companyId, customerId);
    return this.receivableService
      .listNotesByCustomer(companyId, customerId)
      .map((note) => this.toReceivableListItem(note))
      .sort((left, right) => right.issueDate.localeCompare(left.issueDate));
  }

  upsertQuickCustomer(input: UpsertQuickCustomerInput): UpsertQuickCustomerResult {
    const localKey = this.toLocalKey(input.companyId, input.localId);
    const existingLocalId = this.customerIdByLocalKey.get(localKey);
    if (existingLocalId) {
      return {
        customer: this.getCustomer(input.companyId, existingLocalId),
        duplicated: true,
      };
    }

    const now = input.createdAt ?? new Date().toISOString();
    const name = normalizeRequired(input.name, 'Customer name is required.');
    const phone = normalizePhoneRequired(input.phone);
    const phoneKey = this.toPhoneKey(input.companyId, phone);
    const existingPhoneId = this.customerIdByPhoneKey.get(phoneKey);

    if (existingPhoneId) {
      const customer = this.customersById.get(existingPhoneId)!;
      customer.name = name;
      customer.updatedAt = now;
      this.customersById.set(customer.id, customer);
      this.customerIdByLocalKey.set(localKey, customer.id);

      return {
        customer: { ...customer },
        duplicated: true,
      };
    }

    const customer: CustomerRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      name,
      phone,
      createdAt: now,
      updatedAt: now,
      source: 'quick_customer',
    };

    this.customersById.set(customer.id, customer);
    this.customerIdByLocalKey.set(localKey, customer.id);
    this.customerIdByPhoneKey.set(phoneKey, customer.id);

    return {
      customer: { ...customer },
      duplicated: false,
    };
  }

  resolveRemoteCustomerId(companyId: string, localId?: string): string | undefined {
    if (!localId) {
      return undefined;
    }
    return this.customerIdByLocalKey.get(this.toLocalKey(companyId, localId));
  }

  private toCustomerListItem(customer: CustomerRecord): CustomerListItem {
    const sales = this.salesService.listSalesByCustomer(customer.companyId, customer.id);
    const receivables = this.receivableService.listNotesByCustomer(
      customer.companyId,
      customer.id,
    );

    return {
      ...customer,
      totalPurchases: sales.length,
      totalSpentInCents: sales.reduce(
        (accumulator, sale) => accumulator + sale.totalInCents,
        0,
      ),
      lastPurchaseAt: sales.map((sale) => sale.createdAt).sort().at(-1),
      totalOutstandingInCents: receivables.reduce(
        (accumulator, note) => accumulator + note.outstandingAmountInCents,
        0,
      ),
      openReceivablesCount: receivables.filter((note) =>
        note.status === 'pending' || note.status === 'partially_paid',
      ).length,
      overdueReceivablesCount: receivables.filter(
        (note) => note.status === 'overdue',
      ).length,
    };
  }

  private toPurchaseHistoryItem(
    companyId: string,
    sale: SaleRecord,
  ): CustomerPurchaseHistoryItem {
    const receivable = this.receivableService.findBySale(companyId, sale.id);

    return {
      saleId: sale.id,
      createdAt: sale.createdAt,
      subtotalInCents: sale.subtotalInCents,
      discountInCents: sale.discountInCents,
      totalInCents: sale.totalInCents,
      itemCount: sale.items.reduce(
        (accumulator, item) => accumulator + item.quantity,
        0,
      ),
      paymentMethods: sale.payments.map((payment) => payment.method),
      items: sale.items.map((item) => ({ ...item })),
      outstandingAmountInCents: receivable?.outstandingAmountInCents ?? 0,
      receivableStatus: receivable?.status,
      receivableDueDate: receivable?.dueDate,
    };
  }

  private toReceivableListItem(note: ReceivableNote): CustomerReceivableListItem {
    return {
      noteId: note.id,
      saleId: note.saleId,
      originalAmountInCents: note.originalAmountInCents,
      paidAmountInCents: note.paidAmountInCents,
      outstandingAmountInCents: note.outstandingAmountInCents,
      dueDate: note.dueDate,
      issueDate: note.issueDate,
      status: note.status,
    };
  }

  private assertPhoneAvailable(
    companyId: string,
    phone: string,
    ignoreCustomerId?: string,
  ): void {
    const existingId = this.customerIdByPhoneKey.get(this.toPhoneKey(companyId, phone));
    if (existingId && existingId !== ignoreCustomerId) {
      throw new CrmServiceError('Customer phone already exists.');
    }
  }

  private toLocalKey(companyId: string, localId: string): string {
    return `${companyId}:${localId}`;
  }

  private toPhoneKey(companyId: string, phone: string): string {
    return `${companyId}:${phone}`;
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

export class CrmServiceError extends Error {}
