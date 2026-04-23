import type { MaybePromise } from '../catalog/catalog.contract.js';
import type {
  CompanyView,
  UpdateCompanyInput,
} from './company.service.js';

export interface CompanyServiceContract {
  getCurrent(companyId: string): MaybePromise<CompanyView>;
  updateCurrent(input: UpdateCompanyInput): MaybePromise<CompanyView>;
}
