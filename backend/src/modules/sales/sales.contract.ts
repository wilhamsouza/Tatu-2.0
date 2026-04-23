import type { MaybePromise } from '../catalog/catalog.contract.js';
import type {
  CreateSaleInput,
  CreateSaleResult,
  SaleRecord,
} from './sales.service.js';

export interface SalesServiceContract {
  createSale(input: CreateSaleInput): MaybePromise<CreateSaleResult>;
  listSales(companyId: string): MaybePromise<SaleRecord[]>;
  listSalesByCustomer(
    companyId: string,
    customerId: string,
  ): MaybePromise<SaleRecord[]>;
  getSale(companyId: string, saleId: string): MaybePromise<SaleRecord>;
  cancelSale(companyId: string, saleId: string): MaybePromise<SaleRecord>;
}
