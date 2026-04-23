import type { MaybePromise } from '../catalog/catalog.contract.js';
import type { UpsertQuickCustomerResult } from '../crm/crm.service.js';
import type { UpsertQuickCustomerInput } from './sync-customer.service.js';

export interface SyncCustomerServiceContract {
  upsertQuickCustomer(
    input: UpsertQuickCustomerInput,
  ): MaybePromise<UpsertQuickCustomerResult>;
  resolveRemoteCustomerId(
    companyId: string,
    localId?: string,
  ): MaybePromise<string | undefined>;
}
