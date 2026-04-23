import type { MaybePromise } from '../catalog/catalog.contract.js';
import type { ProductVariantView } from '../catalog/catalog.service.js';
import type {
  ApplyStockInput,
  InventoryAdjustmentInput,
  InventoryBalanceRecord,
  InventoryCountInput,
  InventorySummaryItem,
} from './inventory.service.js';

export interface InventoryServiceContract {
  listSummary(
    companyId: string,
    variants: ProductVariantView[],
  ): MaybePromise<InventorySummaryItem[]>;
  getInventorySummaryItem(
    companyId: string,
    variant: ProductVariantView,
  ): MaybePromise<InventorySummaryItem>;
  applyStock(input: ApplyStockInput): MaybePromise<InventoryBalanceRecord>;
  createAdjustment(
    input: InventoryAdjustmentInput,
  ): MaybePromise<InventoryBalanceRecord>;
  recordCount(input: InventoryCountInput): MaybePromise<InventoryBalanceRecord[]>;
}
