import {
  PurchaseStatus,
  type Prisma,
  type PrismaClient,
} from '@prisma/client';

import type { CatalogServiceContract } from '../catalog/catalog.contract.js';
import { CatalogServiceError } from '../catalog/catalog.service.js';
import type { PurchasesServiceContract } from './purchases.contract.js';
import {
  PurchasesServiceError,
  type CreatePurchaseInput,
  type CreateSupplierInput,
  type PurchaseOrderItemRecord,
  type PurchaseOrderRecord,
  type PurchaseOrderView,
  type PurchaseReceiptRecord,
  type ReceivePurchaseInput,
  type SupplierRecord,
} from './purchases.service.js';

type PurchaseDatabase = PrismaClient | Prisma.TransactionClient;

type SupplierModel = {
  id: string;
  companyId: string;
  name: string;
  phone: string | null;
  email: string | null;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
};

type PurchaseItemModel = {
  id: string;
  variantId: string;
  variantDisplayName: string;
  quantityOrdered: number;
  quantityReceived: number;
  unitCostInCents: number;
  lineTotalInCents: number;
};

type ReceiptLineModel = {
  purchaseItemId: string;
  variantId: string;
  quantityReceived: number;
};

type ReceiptModel = {
  id: string;
  purchaseOrderId: string;
  receivedAt: Date;
  createdAt: Date;
  lines: ReceiptLineModel[];
};

type PurchaseModel = {
  id: string;
  companyId: string;
  supplierId: string;
  status: PurchaseStatus;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
  supplier: { name: string };
  items: PurchaseItemModel[];
  receipts: ReceiptModel[];
};

const purchaseInclude = {
  supplier: { select: { name: true } },
  items: true,
  receipts: {
    include: { lines: true },
    orderBy: { createdAt: 'asc' },
  },
} as const;

export class PrismaPurchasesService implements PurchasesServiceContract {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly catalogService: CatalogServiceContract,
  ) {}

  async listSuppliers(companyId: string): Promise<SupplierRecord[]> {
    const suppliers = await this.prisma.supplier.findMany({
      where: { companyId },
      orderBy: { name: 'asc' },
    });

    return suppliers.map(toSupplierRecord);
  }

  async createSupplier(input: CreateSupplierInput): Promise<SupplierRecord> {
    const normalizedName = normalizeRequired(
      input.name,
      'Supplier name is required.',
    );
    const supplier = await this.prisma.supplier.create({
      data: {
        companyId: input.companyId,
        name: normalizedName,
        phone: normalizeOptional(input.phone),
        email: normalizeOptional(input.email),
        notes: normalizeOptional(input.notes),
      },
    });

    return toSupplierRecord(supplier);
  }

  async listPurchases(companyId: string): Promise<PurchaseOrderView[]> {
    const purchases = await this.prisma.purchaseOrder.findMany({
      where: { companyId },
      include: purchaseInclude,
      orderBy: { createdAt: 'desc' },
    });

    return purchases.map((purchase) =>
      toPurchaseView(purchase as PurchaseModel),
    );
  }

  async createPurchase(
    input: CreatePurchaseInput,
  ): Promise<PurchaseOrderView> {
    const supplier = await this.getSupplierOrThrow(
      input.companyId,
      input.supplierId,
    );
    if (input.items.length === 0) {
      throw new PurchasesServiceError(
        'Purchase order must contain at least one item.',
      );
    }

    const items = [];
    for (const item of input.items) {
      if (item.quantityOrdered <= 0) {
        throw new PurchasesServiceError(
          'Ordered quantity must be greater than zero.',
        );
      }
      if (item.unitCostInCents <= 0) {
        throw new PurchasesServiceError(
          'Unit cost must be greater than zero.',
        );
      }

      const variant = await this.getVariantOrThrow(
        input.companyId,
        item.variantId,
      );
      items.push({
        variantId: variant.id,
        variantDisplayName: variant.displayName,
        quantityOrdered: item.quantityOrdered,
        quantityReceived: 0,
        unitCostInCents: item.unitCostInCents,
        lineTotalInCents: item.quantityOrdered * item.unitCostInCents,
      });
    }

    const purchase = await this.prisma.purchaseOrder.create({
      data: {
        companyId: input.companyId,
        supplierId: supplier.id,
        status: PurchaseStatus.PENDING,
        notes: normalizeOptional(input.notes),
        items: { create: items },
      },
      include: purchaseInclude,
    });

    return toPurchaseView(purchase as PurchaseModel);
  }

  async receivePurchase(
    input: ReceivePurchaseInput,
  ): Promise<PurchaseOrderView> {
    if (input.items.length === 0) {
      throw new PurchasesServiceError(
        'Goods receipt must contain at least one item.',
      );
    }

    const receivedAt = parseDate(input.receivedAt);
    return this.prisma.$transaction(async (tx) => {
      const purchase = await tx.purchaseOrder.findFirst({
        where: {
          id: input.purchaseOrderId,
          companyId: input.companyId,
        },
        include: purchaseInclude,
      });

      if (purchase == null) {
        throw new PurchasesServiceError('Purchase order not found.');
      }

      const purchaseModel = purchase as PurchaseModel;
      const itemById = new Map(
        purchaseModel.items.map((item) => [item.id, item]),
      );
      const nextReceivedByItemId = new Map<string, number>();
      const receiptLines = [];

      for (const item of input.items) {
        if (item.quantityReceived <= 0) {
          throw new PurchasesServiceError(
            'Received quantity must be greater than zero.',
          );
        }

        const purchaseItem = itemById.get(item.purchaseItemId);
        if (purchaseItem == null) {
          throw new PurchasesServiceError('Purchase item not found.');
        }

        const alreadyPlannedReceived =
          nextReceivedByItemId.get(purchaseItem.id) ??
          purchaseItem.quantityReceived;
        const remaining = purchaseItem.quantityOrdered - alreadyPlannedReceived;
        if (item.quantityReceived > remaining) {
          throw new PurchasesServiceError(
            'Received quantity exceeds pending quantity.',
          );
        }

        const nextReceived = alreadyPlannedReceived + item.quantityReceived;
        nextReceivedByItemId.set(purchaseItem.id, nextReceived);
        receiptLines.push({
          purchaseItemId: purchaseItem.id,
          variantId: purchaseItem.variantId,
          quantityReceived: item.quantityReceived,
        });
      }

      for (const [purchaseItemId, quantityReceived] of nextReceivedByItemId) {
        await tx.purchaseOrderItem.update({
          where: { id: purchaseItemId },
          data: { quantityReceived },
        });
      }

      await tx.goodsReceipt.create({
        data: {
          purchaseOrderId: purchaseModel.id,
          receivedAt,
          createdAt: receivedAt,
          lines: { create: receiptLines },
        },
      });

      for (const line of receiptLines) {
        await this.applyStockWithClient(tx, {
          companyId: input.companyId,
          variantId: line.variantId,
          quantityDelta: line.quantityReceived,
          reason: 'purchase_receipt',
          referenceId: purchaseModel.id,
          createdAt: receivedAt,
        });
      }

      const nextItems = purchaseModel.items.map((item) => ({
        ...item,
        quantityReceived:
          nextReceivedByItemId.get(item.id) ?? item.quantityReceived,
      }));
      const status = resolvePurchaseStatus(nextItems);
      await tx.purchaseOrder.update({
        where: { id: purchaseModel.id },
        data: { status: toPrismaStatus(status) },
      });

      const updated = await tx.purchaseOrder.findUnique({
        where: { id: purchaseModel.id },
        include: purchaseInclude,
      });

      if (updated == null) {
        throw new PurchasesServiceError('Purchase order not found.');
      }

      return toPurchaseView(updated as PurchaseModel);
    });
  }

  private async getSupplierOrThrow(
    companyId: string,
    id: string,
  ): Promise<SupplierRecord> {
    const supplier = await this.prisma.supplier.findFirst({
      where: { companyId, id },
    });
    if (supplier == null) {
      throw new PurchasesServiceError('Supplier not found.');
    }

    return toSupplierRecord(supplier);
  }

  private async getVariantOrThrow(companyId: string, variantId: string) {
    try {
      return await this.catalogService.getVariant(companyId, variantId);
    } catch (error) {
      if (error instanceof CatalogServiceError) {
        throw new PurchasesServiceError(error.message);
      }
      throw error;
    }
  }

  private async applyStockWithClient(
    db: PurchaseDatabase,
    input: {
      companyId: string;
      variantId: string;
      quantityDelta: number;
      reason: string;
      referenceId?: string;
      createdAt: Date;
    },
  ): Promise<void> {
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
      throw new PurchasesServiceError(
        'Inventory balance cannot become negative.',
      );
    }

    if (current == null) {
      await db.inventoryBalance.create({
        data: {
          companyId: input.companyId,
          variantId: input.variantId,
          quantityOnHand: nextQuantity,
        },
      });
    } else {
      await db.inventoryBalance.update({
        where: {
          companyId_variantId: {
            companyId: input.companyId,
            variantId: input.variantId,
          },
        },
        data: { quantityOnHand: nextQuantity },
      });
    }

    await db.stockMovement.create({
      data: {
        companyId: input.companyId,
        variantId: input.variantId,
        quantityDelta: input.quantityDelta,
        reason: input.reason,
        referenceId: input.referenceId,
        createdAt: input.createdAt,
      },
    });
  }
}

function toSupplierRecord(supplier: SupplierModel): SupplierRecord {
  return {
    id: supplier.id,
    companyId: supplier.companyId,
    name: supplier.name,
    phone: supplier.phone ?? undefined,
    email: supplier.email ?? undefined,
    notes: supplier.notes ?? undefined,
    createdAt: supplier.createdAt.toISOString(),
    updatedAt: supplier.updatedAt.toISOString(),
  };
}

function toPurchaseView(purchase: PurchaseModel): PurchaseOrderView {
  return {
    id: purchase.id,
    companyId: purchase.companyId,
    supplierId: purchase.supplierId,
    supplierName: purchase.supplier.name,
    status: fromPrismaStatus(purchase.status),
    notes: purchase.notes ?? undefined,
    createdAt: purchase.createdAt.toISOString(),
    updatedAt: purchase.updatedAt.toISOString(),
    items: purchase.items.map(toPurchaseItemRecord),
    receipts: purchase.receipts.map(toReceiptRecord),
  };
}

function toPurchaseItemRecord(
  item: PurchaseItemModel,
): PurchaseOrderItemRecord {
  return {
    id: item.id,
    variantId: item.variantId,
    variantDisplayName: item.variantDisplayName,
    quantityOrdered: item.quantityOrdered,
    quantityReceived: item.quantityReceived,
    unitCostInCents: item.unitCostInCents,
    lineTotalInCents: item.lineTotalInCents,
  };
}

function toReceiptRecord(receipt: ReceiptModel): PurchaseReceiptRecord {
  return {
    id: receipt.id,
    purchaseOrderId: receipt.purchaseOrderId,
    receivedAt: receipt.receivedAt.toISOString(),
    createdAt: receipt.createdAt.toISOString(),
    lines: receipt.lines.map((line) => ({
      purchaseItemId: line.purchaseItemId,
      variantId: line.variantId,
      quantityReceived: line.quantityReceived,
    })),
  };
}

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new PurchasesServiceError(message);
  }
  return normalized;
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
}

function parseDate(value?: string): Date {
  return value == null ? new Date() : new Date(value);
}

function fromPrismaStatus(
  status: PurchaseStatus,
): PurchaseOrderRecord['status'] {
  switch (status) {
    case PurchaseStatus.PARTIALLY_RECEIVED:
      return 'partially_received';
    case PurchaseStatus.RECEIVED:
      return 'received';
    default:
      return 'pending';
  }
}

function toPrismaStatus(
  status: PurchaseOrderRecord['status'],
): PurchaseStatus {
  switch (status) {
    case 'partially_received':
      return PurchaseStatus.PARTIALLY_RECEIVED;
    case 'received':
      return PurchaseStatus.RECEIVED;
    default:
      return PurchaseStatus.PENDING;
  }
}

function resolvePurchaseStatus(
  items: PurchaseOrderItemRecord[],
): PurchaseOrderRecord['status'] {
  const totalOrdered = items.reduce(
    (accumulator, item) => accumulator + item.quantityOrdered,
    0,
  );
  const totalReceived = items.reduce(
    (accumulator, item) => accumulator + item.quantityReceived,
    0,
  );

  if (totalReceived <= 0) {
    return 'pending';
  }
  if (totalReceived >= totalOrdered) {
    return 'received';
  }
  return 'partially_received';
}
