import { randomUUID } from 'node:crypto';

import {
  CatalogService,
  CatalogServiceError,
  type ProductVariantView,
} from '../catalog/catalog.service.js';
import { InventoryService } from '../inventory/inventory.service.js';

export interface SupplierRecord {
  id: string;
  companyId: string;
  name: string;
  phone?: string;
  email?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PurchaseOrderItemRecord {
  id: string;
  variantId: string;
  variantDisplayName: string;
  quantityOrdered: number;
  quantityReceived: number;
  unitCostInCents: number;
  lineTotalInCents: number;
}

export interface PurchaseReceiptLineRecord {
  purchaseItemId: string;
  variantId: string;
  quantityReceived: number;
}

export interface PurchaseReceiptRecord {
  id: string;
  purchaseOrderId: string;
  receivedAt: string;
  lines: PurchaseReceiptLineRecord[];
  createdAt: string;
}

export interface PurchaseOrderRecord {
  id: string;
  companyId: string;
  supplierId: string;
  status: 'pending' | 'partially_received' | 'received';
  notes?: string;
  createdAt: string;
  updatedAt: string;
  items: PurchaseOrderItemRecord[];
  receipts: PurchaseReceiptRecord[];
}

export interface PurchaseOrderView extends PurchaseOrderRecord {
  supplierName: string;
}

export interface CreateSupplierInput {
  companyId: string;
  name: string;
  phone?: string;
  email?: string;
  notes?: string;
}

export interface CreatePurchaseInput {
  companyId: string;
  supplierId: string;
  notes?: string;
  items: Array<{
    variantId: string;
    quantityOrdered: number;
    unitCostInCents: number;
  }>;
}

export interface ReceivePurchaseInput {
  companyId: string;
  purchaseOrderId: string;
  receivedAt?: string;
  items: Array<{
    purchaseItemId: string;
    quantityReceived: number;
  }>;
}

export class PurchasesService {
  private readonly suppliersById = new Map<string, SupplierRecord>();
  private readonly purchasesById = new Map<string, PurchaseOrderRecord>();

  constructor(
    private readonly catalogService: CatalogService,
    private readonly inventoryService: InventoryService,
  ) {}

  listSuppliers(companyId: string): SupplierRecord[] {
    return [...this.suppliersById.values()]
      .filter((supplier) => supplier.companyId === companyId)
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  createSupplier(input: CreateSupplierInput): SupplierRecord {
    const normalizedName = input.name.trim();
    if (normalizedName.length === 0) {
      throw new PurchasesServiceError('Supplier name is required.');
    }

    const now = new Date().toISOString();
    const supplier: SupplierRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      name: normalizedName,
      phone: normalizeOptional(input.phone),
      email: normalizeOptional(input.email),
      notes: normalizeOptional(input.notes),
      createdAt: now,
      updatedAt: now,
    };

    this.suppliersById.set(supplier.id, supplier);
    return supplier;
  }

  listPurchases(companyId: string): PurchaseOrderView[] {
    return [...this.purchasesById.values()]
      .filter((purchase) => purchase.companyId === companyId)
      .map((purchase) => this.toPurchaseView(purchase))
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  }

  createPurchase(input: CreatePurchaseInput): PurchaseOrderView {
    const supplier = this.getSupplierOrThrow(input.companyId, input.supplierId);
    if (input.items.length === 0) {
      throw new PurchasesServiceError('Purchase order must contain at least one item.');
    }

    const now = new Date().toISOString();
    const items = input.items.map((item) => {
      if (item.quantityOrdered <= 0) {
        throw new PurchasesServiceError('Ordered quantity must be greater than zero.');
      }
      if (item.unitCostInCents <= 0) {
        throw new PurchasesServiceError('Unit cost must be greater than zero.');
      }

      const variant = this.getVariantOrThrow(input.companyId, item.variantId);
      return {
        id: randomUUID(),
        variantId: variant.id,
        variantDisplayName: variant.displayName,
        quantityOrdered: item.quantityOrdered,
        quantityReceived: 0,
        unitCostInCents: item.unitCostInCents,
        lineTotalInCents: item.quantityOrdered * item.unitCostInCents,
      } satisfies PurchaseOrderItemRecord;
    });

    const purchase: PurchaseOrderRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      supplierId: supplier.id,
      status: 'pending',
      notes: normalizeOptional(input.notes),
      createdAt: now,
      updatedAt: now,
      items,
      receipts: [],
    };

    this.purchasesById.set(purchase.id, purchase);
    return this.toPurchaseView(purchase);
  }

  receivePurchase(input: ReceivePurchaseInput): PurchaseOrderView {
    const purchase = this.getPurchaseOrThrow(input.companyId, input.purchaseOrderId);
    if (input.items.length === 0) {
      throw new PurchasesServiceError('Goods receipt must contain at least one item.');
    }

    const receivedAt = input.receivedAt ?? new Date().toISOString();
    const lines = input.items.map((item) => {
      if (item.quantityReceived <= 0) {
        throw new PurchasesServiceError('Received quantity must be greater than zero.');
      }

      const purchaseItem = purchase.items.find(
        (candidate) => candidate.id === item.purchaseItemId,
      );
      if (!purchaseItem) {
        throw new PurchasesServiceError('Purchase item not found.');
      }

      const remaining = purchaseItem.quantityOrdered - purchaseItem.quantityReceived;
      if (item.quantityReceived > remaining) {
        throw new PurchasesServiceError('Received quantity exceeds pending quantity.');
      }

      purchaseItem.quantityReceived += item.quantityReceived;
      this.inventoryService.applyStock({
        companyId: input.companyId,
        variantId: purchaseItem.variantId,
        quantityDelta: item.quantityReceived,
        reason: 'purchase_receipt',
        referenceId: purchase.id,
        createdAt: receivedAt,
      });

      return {
        purchaseItemId: purchaseItem.id,
        variantId: purchaseItem.variantId,
        quantityReceived: item.quantityReceived,
      } satisfies PurchaseReceiptLineRecord;
    });

    purchase.receipts.push({
      id: randomUUID(),
      purchaseOrderId: purchase.id,
      receivedAt,
      lines,
      createdAt: receivedAt,
    });
    purchase.status = resolvePurchaseStatus(purchase.items);
    purchase.updatedAt = receivedAt;
    this.purchasesById.set(purchase.id, purchase);

    return this.toPurchaseView(purchase);
  }

  private toPurchaseView(purchase: PurchaseOrderRecord): PurchaseOrderView {
    const supplierName = this.suppliersById.get(purchase.supplierId)?.name;
    if (!supplierName) {
      throw new PurchasesServiceError('Supplier not found for purchase order.');
    }

    return {
      ...purchase,
      items: purchase.items.map((item) => ({ ...item })),
      receipts: purchase.receipts.map((receipt) => ({
        ...receipt,
        lines: receipt.lines.map((line) => ({ ...line })),
      })),
      supplierName,
    };
  }

  private getSupplierOrThrow(companyId: string, id: string): SupplierRecord {
    const supplier = this.suppliersById.get(id);
    if (!supplier || supplier.companyId !== companyId) {
      throw new PurchasesServiceError('Supplier not found.');
    }
    return supplier;
  }

  private getPurchaseOrThrow(companyId: string, id: string): PurchaseOrderRecord {
    const purchase = this.purchasesById.get(id);
    if (!purchase || purchase.companyId !== companyId) {
      throw new PurchasesServiceError('Purchase order not found.');
    }
    return purchase;
  }

  private getVariantOrThrow(companyId: string, variantId: string): ProductVariantView {
    try {
      return this.catalogService.getVariant(companyId, variantId);
    } catch (error) {
      if (error instanceof CatalogServiceError) {
        throw new PurchasesServiceError(error.message);
      }
      throw error;
    }
  }
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
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

export class PurchasesServiceError extends Error {}
