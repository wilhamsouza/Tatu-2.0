import type { PrismaClient } from '@prisma/client';

import type { CatalogSnapshotsView, CatalogServiceContract } from './catalog.contract.js';
import {
  CatalogServiceError,
  type CategoryRecord,
  type CategoryView,
  type CreateCategoryInput,
  type CreateProductInput,
  type CreateVariantInput,
  type ProductRecord,
  type ProductVariantRecord,
  type ProductVariantView,
  type ProductView,
  type UpdateCategoryInput,
  type UpdateProductInput,
  type UpdateVariantInput,
} from './catalog.service.js';

type PrismaProductRecord = {
  id: string;
  companyId: string;
  name: string;
  categoryId: string | null;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
};

type ProductWithCategory = PrismaProductRecord & {
  category?: { name: string } | null;
};

type PrismaVariantRecord = {
  id: string;
  companyId: string;
  productId: string;
  barcode: string | null;
  sku: string | null;
  color: string | null;
  size: string | null;
  priceInCents: number;
  promotionalPriceInCents: number | null;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
};

type VariantWithProduct = PrismaVariantRecord & {
  product: PrismaProductRecord & {
    category?: { name: string } | null;
  };
};

const demoCompanyId = 'company_tatuzin';

export class PrismaCatalogService implements CatalogServiceContract {
  private seedPromise?: Promise<void>;

  constructor(private readonly prisma: PrismaClient) {}

  async listCategories(companyId: string): Promise<CategoryView[]> {
    await this.ensureSeeded();
    const categories = await this.prisma.category.findMany({
      where: { companyId },
      orderBy: { name: 'asc' },
    });

    return categories.map(toCategoryView);
  }

  async createCategory(input: CreateCategoryInput): Promise<CategoryView> {
    await this.ensureSeeded();
    const normalizedName = normalizeRequired(
      input.name,
      'Category name is required.',
    );
    await this.assertCategoryNameAvailable(input.companyId, normalizedName);

    const category = await this.prisma.category.create({
      data: {
        companyId: input.companyId,
        name: normalizedName,
        active: input.active ?? true,
      },
    });

    return toCategoryView(category);
  }

  async updateCategory(input: UpdateCategoryInput): Promise<CategoryView> {
    await this.ensureSeeded();
    const category = await this.getCategoryOrThrow(input.companyId, input.id);
    const nextName = input.name?.trim();

    if (
      nextName != null &&
      nextName.length > 0 &&
      nextName.toLowerCase() !== category.name.toLowerCase()
    ) {
      await this.assertCategoryNameAvailable(
        input.companyId,
        nextName,
        category.id,
      );
    }

    const updated = await this.prisma.category.update({
      where: { id: category.id },
      data: {
        ...(nextName != null && nextName.length > 0 ? { name: nextName } : {}),
        ...(input.active != null ? { active: input.active } : {}),
      },
    });

    return toCategoryView(updated);
  }

  async listProducts(companyId: string): Promise<ProductView[]> {
    await this.ensureSeeded();
    const products = await this.prisma.product.findMany({
      where: { companyId },
      include: { category: { select: { name: true } } },
      orderBy: { name: 'asc' },
    });

    return products.map((product) =>
      toProductView(product as ProductWithCategory),
    );
  }

  async createProduct(input: CreateProductInput): Promise<ProductView> {
    await this.ensureSeeded();
    const normalizedName = normalizeRequired(
      input.name,
      'Product name is required.',
    );
    const categoryId = normalizeOptional(input.categoryId);
    if (categoryId != null) {
      await this.getCategoryOrThrow(input.companyId, categoryId);
    }

    const product = await this.prisma.product.create({
      data: {
        companyId: input.companyId,
        name: normalizedName,
        categoryId,
        active: input.active ?? true,
      },
      include: { category: { select: { name: true } } },
    });

    return toProductView(product as ProductWithCategory);
  }

  async updateProduct(input: UpdateProductInput): Promise<ProductView> {
    await this.ensureSeeded();
    const product = await this.getProductOrThrow(input.companyId, input.id);
    const data: {
      name?: string;
      categoryId?: string | null;
      active?: boolean;
    } = {};

    if (input.name != null) {
      data.name = normalizeRequired(input.name, 'Product name is required.');
    }

    if (input.categoryId !== undefined) {
      const nextCategoryId = normalizeOptional(input.categoryId);
      if (nextCategoryId != null) {
        await this.getCategoryOrThrow(input.companyId, nextCategoryId);
      }
      data.categoryId = nextCategoryId ?? null;
    }

    if (input.active != null) {
      data.active = input.active;
    }

    const updated = await this.prisma.product.update({
      where: { id: product.id },
      data,
      include: { category: { select: { name: true } } },
    });

    return toProductView(updated as ProductWithCategory);
  }

  async listVariants(companyId: string): Promise<ProductVariantView[]> {
    await this.ensureSeeded();
    const variants = await this.prisma.productVariant.findMany({
      where: { companyId },
      include: {
        product: {
          include: { category: { select: { name: true } } },
        },
      },
      orderBy: [{ product: { name: 'asc' } }, { color: 'asc' }, { size: 'asc' }],
    });

    return variants
      .map((variant) => toVariantView(variant as VariantWithProduct))
      .sort((left, right) =>
        left.displayName.localeCompare(right.displayName),
      );
  }

  async getVariant(
    companyId: string,
    id: string,
  ): Promise<ProductVariantView> {
    await this.ensureSeeded();
    const variant = await this.getVariantOrThrow(companyId, id);
    return toVariantView(variant);
  }

  async createVariant(input: CreateVariantInput): Promise<ProductVariantView> {
    await this.ensureSeeded();
    const product = await this.getProductOrThrow(
      input.companyId,
      input.productId,
    );
    if (input.priceInCents <= 0) {
      throw new CatalogServiceError('Variant price must be greater than zero.');
    }
    await this.assertVariantUniqueness({
      companyId: input.companyId,
      barcode: input.barcode,
      sku: input.sku,
    });

    const variant = await this.prisma.productVariant.create({
      data: {
        companyId: input.companyId,
        productId: product.id,
        barcode: normalizeOptional(input.barcode),
        sku: normalizeOptional(input.sku),
        color: normalizeOptional(input.color),
        size: normalizeOptional(input.size),
        priceInCents: input.priceInCents,
        promotionalPriceInCents: input.promotionalPriceInCents,
        active: input.active ?? true,
      },
      include: {
        product: {
          include: { category: { select: { name: true } } },
        },
      },
    });

    return toVariantView(variant as VariantWithProduct);
  }

  async updateVariant(input: UpdateVariantInput): Promise<ProductVariantView> {
    await this.ensureSeeded();
    const variant = await this.getVariantOrThrow(input.companyId, input.id);
    await this.assertVariantUniqueness({
      companyId: input.companyId,
      barcode:
        input.barcode === undefined
          ? variant.barcode
          : normalizeOptional(input.barcode),
      sku:
        input.sku === undefined ? variant.sku : normalizeOptional(input.sku),
      ignoreVariantId: variant.id,
    });

    if (input.priceInCents != null && input.priceInCents <= 0) {
      throw new CatalogServiceError('Variant price must be greater than zero.');
    }

    const updated = await this.prisma.productVariant.update({
      where: { id: variant.id },
      data: {
        ...(input.barcode !== undefined
          ? { barcode: normalizeOptional(input.barcode) }
          : {}),
        ...(input.sku !== undefined
          ? { sku: normalizeOptional(input.sku) }
          : {}),
        ...(input.color !== undefined
          ? { color: normalizeOptional(input.color) }
          : {}),
        ...(input.size !== undefined
          ? { size: normalizeOptional(input.size) }
          : {}),
        ...(input.priceInCents != null
          ? { priceInCents: input.priceInCents }
          : {}),
        ...(input.promotionalPriceInCents !== undefined
          ? { promotionalPriceInCents: input.promotionalPriceInCents ?? null }
          : {}),
        ...(input.active != null ? { active: input.active } : {}),
      },
      include: {
        product: {
          include: { category: { select: { name: true } } },
        },
      },
    });

    return toVariantView(updated as VariantWithProduct);
  }

  async buildSaleSnapshots(companyId: string): Promise<CatalogSnapshotsView> {
    await this.ensureSeeded();
    const [categories, products, variants] = await Promise.all([
      this.listCategories(companyId),
      this.listProducts(companyId),
      this.listVariants(companyId),
    ]);
    const timestamps = [
      ...categories.map((item) => item.updatedAt),
      ...products.map((item) => item.updatedAt),
      ...variants.map((item) => item.updatedAt),
    ].sort();

    return {
      companyId,
      categories: categories
        .filter((category) => category.active)
        .map((category) => ({
          id: category.id,
          name: category.name,
          updatedAt: category.updatedAt,
        })),
      products: products
        .filter((product) => product.active)
        .map((product) => ({
          id: product.id,
          name: product.name,
          categoryName: product.categoryName,
          isActive: product.active,
          updatedAt: product.updatedAt,
        })),
      variants: variants
        .filter((variant) => variant.active)
        .map((variant) => ({
          id: variant.id,
          productId: variant.productId,
          barcode: variant.barcode,
          sku: variant.sku,
          displayName: variant.displayName,
          shortName: variant.shortName,
          color: variant.color,
          size: variant.size,
          categoryName: variant.categoryName,
          priceInCents: variant.priceInCents,
          promotionalPriceInCents: variant.promotionalPriceInCents,
          imageUrl: null,
          isActiveForSale: variant.active,
          updatedAt: variant.updatedAt,
        })),
      cursor: timestamps.length === 0 ? null : timestamps.at(-1)!,
    };
  }

  private async getCategoryOrThrow(
    companyId: string,
    id: string,
  ): Promise<CategoryRecord> {
    const category = await this.prisma.category.findFirst({
      where: { companyId, id },
    });
    if (!category) {
      throw new CatalogServiceError('Category not found.');
    }

    return toCategoryView(category);
  }

  private async getProductOrThrow(
    companyId: string,
    id: string,
  ): Promise<ProductRecord> {
    const product = await this.prisma.product.findFirst({
      where: { companyId, id },
    });
    if (!product) {
      throw new CatalogServiceError('Product not found.');
    }

    return toProductRecord(product);
  }

  private async getVariantOrThrow(
    companyId: string,
    id: string,
  ): Promise<VariantWithProduct> {
    const variant = await this.prisma.productVariant.findFirst({
      where: { companyId, id },
      include: {
        product: {
          include: { category: { select: { name: true } } },
        },
      },
    });
    if (!variant) {
      throw new CatalogServiceError('Variant not found.');
    }

    return variant as VariantWithProduct;
  }

  private async assertCategoryNameAvailable(
    companyId: string,
    name: string,
    ignoreCategoryId?: string,
  ): Promise<void> {
    const duplicated = await this.prisma.category.findFirst({
      where: {
        companyId,
        name: { equals: name },
        ...(ignoreCategoryId == null ? {} : { id: { not: ignoreCategoryId } }),
      },
    });
    if (duplicated) {
      throw new CatalogServiceError('Category name already exists.');
    }
  }

  private async assertVariantUniqueness(input: {
    companyId: string;
    barcode?: string | null;
    sku?: string | null;
    ignoreVariantId?: string;
  }): Promise<void> {
    const barcode = normalizeOptional(input.barcode);
    const sku = normalizeOptional(input.sku);
    if (barcode == null && sku == null) {
      return;
    }

    const duplicated = await this.prisma.productVariant.findFirst({
      where: {
        companyId: input.companyId,
        ...(input.ignoreVariantId == null
          ? {}
          : { id: { not: input.ignoreVariantId } }),
        OR: [
          ...(barcode == null ? [] : [{ barcode }]),
          ...(sku == null ? [] : [{ sku }]),
        ],
      },
    });

    if (duplicated) {
      throw new CatalogServiceError('Variant barcode or SKU already exists.');
    }
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= this.seedDemoCatalog();
    return this.seedPromise;
  }

  private async seedDemoCatalog(): Promise<void> {
    await this.prisma.company.upsert({
      where: { id: demoCompanyId },
      create: { id: demoCompanyId, name: 'Tatuzin Demo' },
      update: {},
    });

    await this.prisma.category.upsert({
      where: { id: 'cat_basicos' },
      create: {
        id: 'cat_basicos',
        companyId: demoCompanyId,
        name: 'Basicos',
        active: true,
        createdAt: new Date('2026-04-21T09:00:00.000Z'),
      },
      update: {},
    });
    await this.prisma.category.upsert({
      where: { id: 'cat_acessorios' },
      create: {
        id: 'cat_acessorios',
        companyId: demoCompanyId,
        name: 'Acessorios',
        active: true,
        createdAt: new Date('2026-04-21T09:05:00.000Z'),
      },
      update: {},
    });

    await this.prisma.product.upsert({
      where: { id: 'prod_camiseta_oversized' },
      create: {
        id: 'prod_camiseta_oversized',
        companyId: demoCompanyId,
        categoryId: 'cat_basicos',
        name: 'Camiseta Oversized',
        active: true,
        createdAt: new Date('2026-04-21T09:01:00.000Z'),
      },
      update: {},
    });
    await this.prisma.product.upsert({
      where: { id: 'prod_bolsa_tiracolo' },
      create: {
        id: 'prod_bolsa_tiracolo',
        companyId: demoCompanyId,
        categoryId: 'cat_acessorios',
        name: 'Bolsa Tiracolo',
        active: true,
        createdAt: new Date('2026-04-21T09:06:00.000Z'),
      },
      update: {},
    });

    await this.prisma.productVariant.upsert({
      where: { id: 'var_camiseta_oversized_preta_m' },
      create: {
        id: 'var_camiseta_oversized_preta_m',
        companyId: demoCompanyId,
        productId: 'prod_camiseta_oversized',
        barcode: '7891000000011',
        sku: 'CAM-OVR-PRT-M',
        color: 'Preta',
        size: 'M',
        priceInCents: 9900,
        promotionalPriceInCents: 8900,
        active: true,
        createdAt: new Date('2026-04-21T09:02:00.000Z'),
      },
      update: {},
    });
    await this.prisma.productVariant.upsert({
      where: { id: 'var_bolsa_tiracolo_preta_u' },
      create: {
        id: 'var_bolsa_tiracolo_preta_u',
        companyId: demoCompanyId,
        productId: 'prod_bolsa_tiracolo',
        barcode: '7891000000097',
        sku: 'BOL-TIR-PRT-U',
        color: 'Preta',
        size: 'U',
        priceInCents: 15900,
        active: true,
        createdAt: new Date('2026-04-21T09:07:00.000Z'),
      },
      update: {},
    });
  }
}

function toCategoryView(category: {
  id: string;
  companyId: string;
  name: string;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}): CategoryView {
  return {
    id: category.id,
    companyId: category.companyId,
    name: category.name,
    active: category.active,
    createdAt: category.createdAt.toISOString(),
    updatedAt: category.updatedAt.toISOString(),
  };
}

function toProductRecord(product: {
  id: string;
  companyId: string;
  name: string;
  categoryId: string | null;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}): ProductRecord {
  return {
    id: product.id,
    companyId: product.companyId,
    name: product.name,
    categoryId: product.categoryId ?? undefined,
    active: product.active,
    createdAt: product.createdAt.toISOString(),
    updatedAt: product.updatedAt.toISOString(),
  };
}

function toProductView(product: ProductWithCategory): ProductView {
  return {
    ...toProductRecord(product),
    categoryName: product.category?.name,
  };
}

function toVariantRecord(variant: {
  id: string;
  companyId: string;
  productId: string;
  barcode: string | null;
  sku: string | null;
  color: string | null;
  size: string | null;
  priceInCents: number;
  promotionalPriceInCents: number | null;
  active: boolean;
  createdAt: Date;
  updatedAt: Date;
}): ProductVariantRecord {
  return {
    id: variant.id,
    companyId: variant.companyId,
    productId: variant.productId,
    barcode: variant.barcode ?? undefined,
    sku: variant.sku ?? undefined,
    color: variant.color ?? undefined,
    size: variant.size ?? undefined,
    priceInCents: variant.priceInCents,
    promotionalPriceInCents: variant.promotionalPriceInCents ?? undefined,
    active: variant.active,
    createdAt: variant.createdAt.toISOString(),
    updatedAt: variant.updatedAt.toISOString(),
  };
}

function toVariantView(variant: VariantWithProduct): ProductVariantView {
  const productName = variant.product.name;
  const parts = [productName, variant.color, variant.size].filter(Boolean);
  const shortParts = [variant.color, variant.size].filter(Boolean);

  return {
    ...toVariantRecord(variant),
    productName,
    categoryName: variant.product.category?.name,
    displayName: parts.join(' '),
    shortName: shortParts.join(' ').trim() || productName,
  };
}

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new CatalogServiceError(message);
  }
  return normalized;
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
}
