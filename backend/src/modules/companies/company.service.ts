import { demoUsers } from '../auth/demo-users.js';

export interface CompanyView {
  id: string;
  name: string;
  createdAt: string;
  updatedAt: string;
}

export interface UpdateCompanyInput {
  companyId: string;
  name: string;
}

const [demoUser] = demoUsers;
const now = new Date().toISOString();

export class CompanyService {
  private readonly companies = new Map<string, CompanyView>([
    [
      demoUser.companyId,
      {
        id: demoUser.companyId,
        name: demoUser.companyName,
        createdAt: now,
        updatedAt: now,
      },
    ],
  ]);

  getCurrent(companyId: string): CompanyView {
    const company = this.companies.get(companyId);
    if (company == null) {
      throw new CompanyServiceError('Company not found.');
    }
    return company;
  }

  updateCurrent(input: UpdateCompanyInput): CompanyView {
    const company = this.getCurrent(input.companyId);
    const name = normalizeRequired(input.name, 'Company name is required.');
    const updated = {
      ...company,
      name,
      updatedAt: new Date().toISOString(),
    };
    this.companies.set(input.companyId, updated);
    return updated;
  }
}

export class CompanyServiceError extends Error {}

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new CompanyServiceError(message);
  }
  return normalized;
}
