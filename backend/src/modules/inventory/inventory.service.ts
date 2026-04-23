import { randomUUID } from 'node:crypto';

import type { ProductVariantView } from '../catalog/catalog.service.js';

export interface InventoryBalanceRecord {
  companyId: string;
  variantId: string;
  quantityOnHand: number;
  updatedAt: string;
}

export interface InventorySummaryItem extends InventoryBalanceRecord {
  productId: string;
  productName: string;
  variantDisplayName: string;
  sku?: string;
  barcode?: string;
  color?: string;
  size?: string;
}

export interface StockMovementRecord {
  id: string;
  companyId: string;
  variantId: string;
  quantityDelta: number;
  reason: string;
  referenceId?: string;
  createdAt: string;
}

export interface ApplyStockInput {
  companyId: string;
  variantId: string;
  quantityDelta: number;
  reason: string;
  referenceId?: string;
  createdAt?: string;
}

export interface InventoryAdjustmentInput {
  companyId: string;
  variantId: string;
  quantityDelta: number;
  reason?: string;
  createdAt?: string;
}

export interface InventoryCountInput {
  companyId: string;
  items: Array<{
    variantId: string;
    countedQuantity: number;
  }>;
  createdAt?: string;
}

export class InventoryService {
  private readonly balancesByKey = new Map<string, InventoryBalanceRecord>();
  private readonly movementsById = new Map<string, StockMovementRecord>();

  constructor() {
    this.seed();
  }

  listSummary(
    companyId: string,
    variants: ProductVariantView[],
  ): InventorySummaryItem[] {
    return variants
      .map((variant) => this.getInventorySummaryItem(companyId, variant))
      .sort((left, right) =>
        left.variantDisplayName.localeCompare(right.variantDisplayName),
      );
  }

  getInventorySummaryItem(
    companyId: string,
    variant: ProductVariantView,
  ): InventorySummaryItem {
    const balance = this.loadBalance(companyId, variant.id);
    return {
      ...balance,
      productId: variant.productId,
      productName: variant.productName,
      variantDisplayName: variant.displayName,
      sku: variant.sku,
      barcode: variant.barcode,
      color: variant.color,
      size: variant.size,
    };
  }

  applyStock(input: ApplyStockInput): InventoryBalanceRecord {
    if (input.quantityDelta === 0) {
      throw new InventoryServiceError('Stock movement must change inventory.');
    }

    const balance = this.loadBalance(input.companyId, input.variantId);
    const nextQuantity = balance.quantityOnHand + input.quantityDelta;
    if (nextQuantity < 0) {
      throw new InventoryServiceError('Inventory balance cannot become negative.');
    }

    const occurredAt = input.createdAt ?? new Date().toISOString();
    const nextBalance: InventoryBalanceRecord = {
      companyId: input.companyId,
      variantId: input.variantId,
      quantityOnHand: nextQuantity,
      updatedAt: occurredAt,
    };
    this.balancesByKey.set(this.toBalanceKey(input.companyId, input.variantId), nextBalance);

    const movement: StockMovementRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      variantId: input.variantId,
      quantityDelta: input.quantityDelta,
      reason: input.reason,
      referenceId: input.referenceId,
      createdAt: occurredAt,
    };
    this.movementsById.set(movement.id, movement);

    return nextBalance;
  }

  createAdjustment(input: InventoryAdjustmentInput): InventoryBalanceRecord {
    return this.applyStock({
      companyId: input.companyId,
      variantId: input.variantId,
      quantityDelta: input.quantityDelta,
      reason: input.reason ?? 'manual_adjustment',
      createdAt: input.createdAt,
    });
  }

  recordCount(input: InventoryCountInput): InventoryBalanceRecord[] {
    if (input.items.length === 0) {
      throw new InventoryServiceError('Inventory count must have items.');
    }

    return input.items.map((item) => {
      if (item.countedQuantity < 0) {
        throw new InventoryServiceError(
          'Counted quantity cannot be negative.',
        );
      }
      const current = this.loadBalance(input.companyId, item.variantId);
      const quantityDelta = item.countedQuantity - current.quantityOnHand;
      if (quantityDelta === 0) {
        return current;
      }
      return this.applyStock({
        companyId: input.companyId,
        variantId: item.variantId,
        quantityDelta,
        reason: 'inventory_count',
        createdAt: input.createdAt,
      });
    });
  }

  private loadBalance(companyId: string, variantId: string): InventoryBalanceRecord {
    const key = this.toBalanceKey(companyId, variantId);
    return this.balancesByKey.get(key) ?? {
      companyId,
      variantId,
      quantityOnHand: 0,
      updatedAt: new Date(0).toISOString(),
    };
  }

  private toBalanceKey(companyId: string, variantId: string): string {
    return `${companyId}:${variantId}`;
  }

  private seed(): void {
    const companyId = 'company_tatuzin';
    this.balancesByKey.set(this.toBalanceKey(companyId, 'var_camiseta_oversized_preta_m'), {
      companyId,
      variantId: 'var_camiseta_oversized_preta_m',
      quantityOnHand: 12,
      updatedAt: '2026-04-21T09:15:00.000Z',
    });
    this.balancesByKey.set(this.toBalanceKey(companyId, 'var_bolsa_tiracolo_preta_u'), {
      companyId,
      variantId: 'var_bolsa_tiracolo_preta_u',
      quantityOnHand: 6,
      updatedAt: '2026-04-21T09:16:00.000Z',
    });
  }
}

export class InventoryServiceError extends Error {}
