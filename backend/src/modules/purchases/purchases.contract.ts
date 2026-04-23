import type { MaybePromise } from '../catalog/catalog.contract.js';
import type {
  CreatePurchaseInput,
  CreateSupplierInput,
  PurchaseOrderView,
  ReceivePurchaseInput,
  SupplierRecord,
} from './purchases.service.js';

export interface PurchasesServiceContract {
  listSuppliers(companyId: string): MaybePromise<SupplierRecord[]>;
  createSupplier(input: CreateSupplierInput): MaybePromise<SupplierRecord>;
  listPurchases(companyId: string): MaybePromise<PurchaseOrderView[]>;
  createPurchase(input: CreatePurchaseInput): MaybePromise<PurchaseOrderView>;
  receivePurchase(input: ReceivePurchaseInput): MaybePromise<PurchaseOrderView>;
}
