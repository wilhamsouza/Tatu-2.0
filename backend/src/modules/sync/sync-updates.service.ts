export type SyncUpdateType =
  | 'category_snapshot'
  | 'product_snapshot'
  | 'variant_snapshot'
  | 'price_snapshot';

export interface SyncUpdateRecord {
  cursor: string;
  updateType: SyncUpdateType;
  entityRemoteId: string;
  payload: Record<string, unknown>;
  updatedAt: string;
}

interface PullUpdatesInput {
  companyId: string;
  cursor?: string;
  limit: number;
}

interface PullUpdatesResult {
  updates: SyncUpdateRecord[];
  nextCursor: string | null;
}

const catalogSeedUpdates: SyncUpdateRecord[] = [
  {
    cursor: '0001',
    updateType: 'category_snapshot',
    entityRemoteId: 'cat_basicos',
    updatedAt: '2026-04-21T09:00:00.000Z',
    payload: {
      id: 'cat_basicos',
      name: 'Basicos',
      updatedAt: '2026-04-21T09:00:00.000Z',
    },
  },
  {
    cursor: '0002',
    updateType: 'product_snapshot',
    entityRemoteId: 'prod_camiseta_oversized',
    updatedAt: '2026-04-21T09:01:00.000Z',
    payload: {
      id: 'prod_camiseta_oversized',
      name: 'Camiseta Oversized',
      categoryName: 'Basicos',
      isActive: true,
      updatedAt: '2026-04-21T09:01:00.000Z',
    },
  },
  {
    cursor: '0003',
    updateType: 'variant_snapshot',
    entityRemoteId: 'var_camiseta_oversized_preta_m',
    updatedAt: '2026-04-21T09:02:00.000Z',
    payload: {
      id: 'var_camiseta_oversized_preta_m',
      productId: 'prod_camiseta_oversized',
      barcode: '7891000000011',
      sku: 'CAM-OVR-PRT-M',
      displayName: 'Camiseta Oversized Preta M',
      shortName: 'Oversized Preta M',
      color: 'Preta',
      size: 'M',
      categoryName: 'Basicos',
      priceInCents: 9900,
      promotionalPriceInCents: 8900,
      imageUrl: null,
      isActiveForSale: true,
      updatedAt: '2026-04-21T09:02:00.000Z',
    },
  },
  {
    cursor: '0004',
    updateType: 'price_snapshot',
    entityRemoteId: 'price_var_camiseta_oversized_preta_m',
    updatedAt: '2026-04-21T09:03:00.000Z',
    payload: {
      id: 'price_var_camiseta_oversized_preta_m',
      variantRemoteId: 'var_camiseta_oversized_preta_m',
      priceInCents: 9900,
      promotionalPriceInCents: 8900,
      startsAt: null,
      endsAt: null,
      updatedAt: '2026-04-21T09:03:00.000Z',
    },
  },
];

export class SyncUpdatesService {
  pullUpdates(input: PullUpdatesInput): PullUpdatesResult {
    void input.companyId;

    const startIndex =
      input.cursor == null
        ? 0
        : catalogSeedUpdates.findIndex((update) => update.cursor === input.cursor) +
          1;
    const updates = catalogSeedUpdates.slice(startIndex, startIndex + input.limit);
    const nextCursor =
      updates.length === 0 ? input.cursor ?? null : updates[updates.length - 1]!.cursor;

    return {
      updates,
      nextCursor,
    };
  }
}
