import type { PrismaClient } from '@prisma/client';

import type {
  CustomerRecord,
  UpsertQuickCustomerResult,
} from '../crm/crm.service.js';
import type { SyncCustomerServiceContract } from './sync-customer.contract.js';
import type { UpsertQuickCustomerInput } from './sync-customer.service.js';

export class PrismaSyncCustomerService implements SyncCustomerServiceContract {
  private readonly customerIdByLocalKey = new Map<string, string>();

  constructor(private readonly prisma: PrismaClient) {}

  async upsertQuickCustomer(
    input: UpsertQuickCustomerInput,
  ): Promise<UpsertQuickCustomerResult> {
    await this.ensureCompany(input.companyId);

    const localKey = this.toLocalKey(input.companyId, input.localId);
    const existingLocalId = this.customerIdByLocalKey.get(localKey);
    if (existingLocalId != null) {
      return {
        customer: await this.getCustomer(input.companyId, existingLocalId),
        duplicated: true,
      };
    }

    const name = normalizeRequired(input.name, 'Customer name is required.');
    const phone = normalizePhoneRequired(input.phone);
    const existingPhone = await this.prisma.customer.findUnique({
      where: { companyId_phone: { companyId: input.companyId, phone } },
    });

    if (existingPhone != null) {
      const updated = await this.prisma.customer.update({
        where: { id: existingPhone.id },
        data: {
          name,
          source:
            existingPhone.source === 'manual' ? 'manual' : 'quick_customer',
        },
      });
      this.customerIdByLocalKey.set(localKey, updated.id);

      return {
        customer: toCustomerRecord(updated),
        duplicated: true,
      };
    }

    const createdAt = parseDate(input.createdAt);
    const customer = await this.prisma.customer.create({
      data: {
        companyId: input.companyId,
        name,
        phone,
        source: 'quick_customer',
        createdAt,
      },
    });
    this.customerIdByLocalKey.set(localKey, customer.id);

    return {
      customer: toCustomerRecord(customer),
      duplicated: false,
    };
  }

  resolveRemoteCustomerId(
    companyId: string,
    localId?: string,
  ): string | undefined {
    if (!localId) {
      return undefined;
    }

    return this.customerIdByLocalKey.get(this.toLocalKey(companyId, localId));
  }

  private async getCustomer(
    companyId: string,
    id: string,
  ): Promise<CustomerRecord> {
    const customer = await this.prisma.customer.findFirst({
      where: { companyId, id },
    });
    if (customer == null) {
      throw new Error('Customer not found.');
    }

    return toCustomerRecord(customer);
  }

  private async ensureCompany(companyId: string): Promise<void> {
    await this.prisma.company.upsert({
      where: { id: companyId },
      create: { id: companyId, name: 'Tatuzin Demo' },
      update: {},
    });
  }

  private toLocalKey(companyId: string, localId: string): string {
    return `${companyId}:${localId}`;
  }
}

function toCustomerRecord(customer: {
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
}): CustomerRecord {
  return {
    id: customer.id,
    companyId: customer.companyId,
    name: customer.name,
    phone: customer.phone,
    email: customer.email ?? undefined,
    address: customer.address ?? undefined,
    notes: customer.notes ?? undefined,
    source: customer.source === 'quick_customer' ? 'quick_customer' : 'manual',
    createdAt: customer.createdAt.toISOString(),
    updatedAt: customer.updatedAt.toISOString(),
  };
}

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new Error(message);
  }
  return normalized;
}

function normalizePhoneRequired(value: string): string {
  const normalized = value.replace(/\D/g, '');
  if (normalized.length === 0) {
    throw new Error('Customer phone is required.');
  }
  return normalized;
}

function parseDate(value?: string): Date {
  return value == null ? new Date() : new Date(value);
}
