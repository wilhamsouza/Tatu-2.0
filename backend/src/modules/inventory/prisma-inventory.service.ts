import type { Prisma, PrismaClient } from '@prisma/client';

import type { ProductVariantView } from '../catalog/catalog.service.js';
import type { InventoryServiceContract } from './inventory.contract.js';
import {
  InventoryServiceError,
  type ApplyStockInput,
  type InventoryAdjustmentInput,
  type InventoryBalanceRecord,
  type InventoryCountInput,
  type InventorySummaryItem,
} from './inventory.service.js';

type InventoryBalanceModel = {
  companyId: string;
  variantId: string;
  quantityOnHand: number;
  updatedAt: Date;
};

type InventoryDatabase = PrismaClient | Prisma.TransactionClient;

const demoBalances = [
  {
    companyId: 'company_tatuzin',
    variantId: 'var_camiseta_oversized_preta_m',
    quantityOnHand: 12,
  },
  {
    companyId: 'company_tatuzin',
    variantId: 'var_bolsa_tiracolo_preta_u',
    quantityOnHand: 6,
  },
];

export class PrismaInventoryService implements InventoryServiceContract {
  private seedPromise?: Promise<void>;

  constructor(private readonly prisma: PrismaClient) {}

  async listSummary(
    companyId: string,
    variants: ProductVariantView[],
  ): Promise<InventorySummaryItem[]> {
    await this.ensureSeeded();
    const variantIds = variants.map((variant) => variant.id);
    const balances = await this.prisma.inventoryBalance.findMany({
      where: {
        companyId,
        variantId: { in: variantIds },
      },
    });
    const balancesByVariantId = new Map(
      balances.map((balance) => [balance.variantId, toBalanceRecord(balance)]),
    );

    return variants
      .map((variant) =>
        toSummaryItem(
          balancesByVariantId.get(variant.id) ??
            createEmptyBalance(companyId, variant.id),
          variant,
        ),
      )
      .sort((left, right) =>
        left.variantDisplayName.localeCompare(right.variantDisplayName),
      );
  }

  async getInventorySummaryItem(
    companyId: string,
    variant: ProductVariantView,
  ): Promise<InventorySummaryItem> {
    await this.ensureSeeded();
    const balance = await this.loadBalance(companyId, variant.id);
    return toSummaryItem(balance, variant);
  }

  async applyStock(input: ApplyStockInput): Promise<InventoryBalanceRecord> {
    if (input.quantityDelta === 0) {
      throw new InventoryServiceError('Stock movement must change inventory.');
    }

    await this.ensureSeeded();
    const occurredAt = parseDate(input.createdAt);
    return this.prisma.$transaction((tx) =>
      this.applyStockWithClient(tx, input, occurredAt),
    );
  }

  createAdjustment(
    input: InventoryAdjustmentInput,
  ): Promise<InventoryBalanceRecord> {
    return this.applyStock({
      companyId: input.companyId,
      variantId: input.variantId,
      quantityDelta: input.quantityDelta,
      reason: input.reason ?? 'manual_adjustment',
      createdAt: input.createdAt,
    });
  }

  async recordCount(
    input: InventoryCountInput,
  ): Promise<InventoryBalanceRecord[]> {
    if (input.items.length === 0) {
      throw new InventoryServiceError('Inventory count must have items.');
    }

    await this.ensureSeeded();
    const occurredAt = parseDate(input.createdAt);
    return this.prisma.$transaction(async (tx) => {
      const balances: InventoryBalanceRecord[] = [];

      for (const item of input.items) {
        if (item.countedQuantity < 0) {
          throw new InventoryServiceError(
            'Counted quantity cannot be negative.',
          );
        }

        const current = await this.loadBalanceWithClient(
          tx,
          input.companyId,
          item.variantId,
        );
        const quantityDelta = item.countedQuantity - current.quantityOnHand;
        if (quantityDelta === 0) {
          balances.push(current);
          continue;
        }

        balances.push(
          await this.applyStockWithClient(
            tx,
            {
              companyId: input.companyId,
              variantId: item.variantId,
              quantityDelta,
              reason: 'inventory_count',
              createdAt: input.createdAt,
            },
            occurredAt,
          ),
        );
      }

      return balances;
    });
  }

  private async loadBalance(
    companyId: string,
    variantId: string,
  ): Promise<InventoryBalanceRecord> {
    return this.loadBalanceWithClient(this.prisma, companyId, variantId);
  }

  private async loadBalanceWithClient(
    db: InventoryDatabase,
    companyId: string,
    variantId: string,
  ): Promise<InventoryBalanceRecord> {
    const balance = await db.inventoryBalance.findUnique({
      where: { companyId_variantId: { companyId, variantId } },
    });

    return balance == null
      ? createEmptyBalance(companyId, variantId)
      : toBalanceRecord(balance);
  }

  private async applyStockWithClient(
    db: InventoryDatabase,
    input: ApplyStockInput,
    occurredAt: Date,
  ): Promise<InventoryBalanceRecord> {
    const current = await db.inventoryBalance.findUnique({
      where: {
        companyId_variantId: {
          companyId: input.companyId,
          variantId: input.variantId,
        },
      },
    });
    const nextQuantity = (current?.quantityOnHand ?? 0) + input.quantityDelta;
    if (nextQuantity < 0) {
      throw new InventoryServiceError(
        'Inventory balance cannot become negative.',
      );
    }

    const balance =
      current == null
        ? await db.inventoryBalance.create({
            data: {
              companyId: input.companyId,
              variantId: input.variantId,
              quantityOnHand: nextQuantity,
            },
          })
        : await db.inventoryBalance.update({
            where: {
              companyId_variantId: {
                companyId: input.companyId,
                variantId: input.variantId,
              },
            },
            data: { quantityOnHand: nextQuantity },
          });

    await db.stockMovement.create({
      data: {
        companyId: input.companyId,
        variantId: input.variantId,
        quantityDelta: input.quantityDelta,
        reason: input.reason,
        referenceId: input.referenceId,
        createdAt: occurredAt,
      },
    });

    return toBalanceRecord(balance);
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= this.seedDemoBalances();
    return this.seedPromise;
  }

  private async seedDemoBalances(): Promise<void> {
    const availableVariants = await this.prisma.productVariant.findMany({
      where: {
        companyId: 'company_tatuzin',
        id: { in: demoBalances.map((balance) => balance.variantId) },
      },
      select: { id: true },
    });
    const availableVariantIds = new Set(
      availableVariants.map((variant) => variant.id),
    );

    for (const balance of demoBalances) {
      if (!availableVariantIds.has(balance.variantId)) {
        continue;
      }

      await this.prisma.inventoryBalance.upsert({
        where: {
          companyId_variantId: {
            companyId: balance.companyId,
            variantId: balance.variantId,
          },
        },
        create: balance,
        update: {},
      });
    }
  }
}

function toBalanceRecord(
  balance: InventoryBalanceModel,
): InventoryBalanceRecord {
  return {
    companyId: balance.companyId,
    variantId: balance.variantId,
    quantityOnHand: balance.quantityOnHand,
    updatedAt: balance.updatedAt.toISOString(),
  };
}

function toSummaryItem(
  balance: InventoryBalanceRecord,
  variant: ProductVariantView,
): InventorySummaryItem {
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

function createEmptyBalance(
  companyId: string,
  variantId: string,
): InventoryBalanceRecord {
  return {
    companyId,
    variantId,
    quantityOnHand: 0,
    updatedAt: new Date(0).toISOString(),
  };
}

function parseDate(value?: string): Date {
  return value == null ? new Date() : new Date(value);
}
