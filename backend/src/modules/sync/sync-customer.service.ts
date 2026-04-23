import {
  CrmService,
  type CustomerRecord,
  type UpsertQuickCustomerResult,
} from '../crm/crm.service.js';

export interface SyncedCustomerRecord extends CustomerRecord {}

export interface UpsertQuickCustomerInput {
  companyId: string;
  localId: string;
  name: string;
  phone: string;
  createdAt?: string;
}

export class SyncCustomerService {
  constructor(private readonly crmService: CrmService) {}

  upsertQuickCustomer(
    input: UpsertQuickCustomerInput,
  ): UpsertQuickCustomerResult {
    return this.crmService.upsertQuickCustomer(input);
  }

  resolveRemoteCustomerId(companyId: string, localId?: string): string | undefined {
    return this.crmService.resolveRemoteCustomerId(companyId, localId);
  }
}
