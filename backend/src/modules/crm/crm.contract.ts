import type { MaybePromise } from '../catalog/catalog.contract.js';
import type {
  CreateCustomerInput,
  CustomerHistoryView,
  CustomerListItem,
  CustomerReceivableListItem,
  CustomerRecord,
  CustomerSummaryView,
  UpdateCustomerInput,
} from './crm.service.js';

export interface CrmServiceContract {
  listCustomers(
    companyId: string,
    query?: string,
  ): MaybePromise<CustomerListItem[]>;
  createCustomer(input: CreateCustomerInput): MaybePromise<CustomerRecord>;
  updateCustomer(input: UpdateCustomerInput): MaybePromise<CustomerRecord>;
  getCustomer(companyId: string, id: string): MaybePromise<CustomerRecord>;
  getCustomerReceivables(
    companyId: string,
    customerId: string,
  ): MaybePromise<CustomerReceivableListItem[]>;
  getCustomerHistory(
    companyId: string,
    customerId: string,
  ): MaybePromise<CustomerHistoryView>;
  getCustomerSummary(
    companyId: string,
    customerId: string,
  ): MaybePromise<CustomerSummaryView>;
  exportSegmentCsv(companyId: string, query?: string): MaybePromise<string>;
}
