import type { PrismaClient } from '@prisma/client';

import { seedDemoIdentity } from '../auth/prisma-identity.seed.js';
import type { CompanyServiceContract } from './company.contract.js';
import {
  CompanyServiceError,
  type CompanyView,
  type UpdateCompanyInput,
} from './company.service.js';

export class PrismaCompanyService implements CompanyServiceContract {
  private seedPromise?: Promise<void>;

  constructor(private readonly prisma: PrismaClient) {}

  async getCurrent(companyId: string): Promise<CompanyView> {
    await this.ensureSeeded();
    const company = await this.prisma.company.findUnique({
      where: { id: companyId },
    });
    if (company == null) {
      throw new CompanyServiceError('Company not found.');
    }
    return toCompanyView(company);
  }

  async updateCurrent(input: UpdateCompanyInput): Promise<CompanyView> {
    await this.ensureSeeded();
    const name = normalizeRequired(input.name, 'Company name is required.');
    const company = await this.prisma.company.update({
      where: { id: input.companyId },
      data: { name },
    });
    return toCompanyView(company);
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= seedDemoIdentity(this.prisma);
    return this.seedPromise;
  }
}

function toCompanyView(company: {
  id: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
}): CompanyView {
  return {
    id: company.id,
    name: company.name,
    createdAt: company.createdAt.toISOString(),
    updatedAt: company.updatedAt.toISOString(),
  };
}

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new CompanyServiceError(message);
  }
  return normalized;
}
