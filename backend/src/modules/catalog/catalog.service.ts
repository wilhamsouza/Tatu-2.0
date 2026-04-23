import { randomUUID } from 'node:crypto';

export interface CategoryRecord {
  id: string;
  companyId: string;
  name: string;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ProductRecord {
  id: string;
  companyId: string;
  name: string;
  categoryId?: string;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ProductVariantRecord {
  id: string;
  companyId: string;
  productId: string;
  barcode?: string;
  sku?: string;
  color?: string;
  size?: string;
  priceInCents: number;
  promotionalPriceInCents?: number;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CategoryView extends CategoryRecord {}

export interface ProductView extends ProductRecord {
  categoryName?: string;
}

export interface ProductVariantView extends ProductVariantRecord {
  productName: string;
  categoryName?: string;
  displayName: string;
  shortName: string;
}

export interface CreateCategoryInput {
  companyId: string;
  name: string;
  active?: boolean;
}

export interface UpdateCategoryInput {
  companyId: string;
  id: string;
  name?: string;
  active?: boolean;
}

export interface CreateProductInput {
  companyId: string;
  name: string;
  categoryId?: string;
  active?: boolean;
}

export interface UpdateProductInput {
  companyId: string;
  id: string;
  name?: string;
  categoryId?: string | null;
  active?: boolean;
}

export interface CreateVariantInput {
  companyId: string;
  productId: string;
  barcode?: string;
  sku?: string;
  color?: string;
  size?: string;
  priceInCents: number;
  promotionalPriceInCents?: number;
  active?: boolean;
}

export interface UpdateVariantInput {
  companyId: string;
  id: string;
  barcode?: string | null;
  sku?: string | null;
  color?: string | null;
  size?: string | null;
  priceInCents?: number;
  promotionalPriceInCents?: number | null;
  active?: boolean;
}

export class CatalogService {
  private readonly categoriesById = new Map<string, CategoryRecord>();
  private readonly productsById = new Map<string, ProductRecord>();
  private readonly variantsById = new Map<string, ProductVariantRecord>();

  constructor() {
    this.seed();
  }

  listCategories(companyId: string): CategoryView[] {
    return [...this.categoriesById.values()]
      .filter((category) => category.companyId === companyId)
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  createCategory(input: CreateCategoryInput): CategoryView {
    const normalizedName = input.name.trim();
    if (normalizedName.length === 0) {
      throw new CatalogServiceError('Category name is required.');
    }
    this.assertCategoryNameAvailable(input.companyId, normalizedName);

    const now = new Date().toISOString();
    const category: CategoryRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      name: normalizedName,
      active: input.active ?? true,
      createdAt: now,
      updatedAt: now,
    };

    this.categoriesById.set(category.id, category);
    return category;
  }

  updateCategory(input: UpdateCategoryInput): CategoryView {
    const category = this.getCategoryOrThrow(input.companyId, input.id);
    const nextName = input.name?.trim();
    if (nextName != null && nextName.length > 0 && nextName !== category.name) {
      this.assertCategoryNameAvailable(input.companyId, nextName, category.id);
      category.name = nextName;
    }

    if (input.active != null) {
      category.active = input.active;
    }

    category.updatedAt = new Date().toISOString();
    this.categoriesById.set(category.id, category);
    return category;
  }

  listProducts(companyId: string): ProductView[] {
    return [...this.productsById.values()]
      .filter((product) => product.companyId === companyId)
      .map((product) => this.toProductView(product))
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  createProduct(input: CreateProductInput): ProductView {
    const normalizedName = input.name.trim();
    if (normalizedName.length === 0) {
      throw new CatalogServiceError('Product name is required.');
    }

    const categoryId = input.categoryId?.trim() || undefined;
    if (categoryId != null) {
      this.getCategoryOrThrow(input.companyId, categoryId);
    }

    const now = new Date().toISOString();
    const product: ProductRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      name: normalizedName,
      categoryId,
      active: input.active ?? true,
      createdAt: now,
      updatedAt: now,
    };

    this.productsById.set(product.id, product);
    return this.toProductView(product);
  }

  updateProduct(input: UpdateProductInput): ProductView {
    const product = this.getProductOrThrow(input.companyId, input.id);

    if (input.name != null) {
      const normalizedName = input.name.trim();
      if (normalizedName.length === 0) {
        throw new CatalogServiceError('Product name is required.');
      }
      product.name = normalizedName;
    }

    if (input.categoryId !== undefined) {
      const nextCategoryId = input.categoryId?.trim() || undefined;
      if (nextCategoryId != null) {
        this.getCategoryOrThrow(input.companyId, nextCategoryId);
      }
      product.categoryId = nextCategoryId;
    }

    if (input.active != null) {
      product.active = input.active;
    }

    product.updatedAt = new Date().toISOString();
    this.productsById.set(product.id, product);
    return this.toProductView(product);
  }

  listVariants(companyId: string): ProductVariantView[] {
    return [...this.variantsById.values()]
      .filter((variant) => variant.companyId === companyId)
      .map((variant) => this.toVariantView(variant))
      .sort((left, right) => left.displayName.localeCompare(right.displayName));
  }

  getVariant(companyId: string, id: string): ProductVariantView {
    return this.toVariantView(this.getVariantOrThrow(companyId, id));
  }

  createVariant(input: CreateVariantInput): ProductVariantView {
    const product = this.getProductOrThrow(input.companyId, input.productId);
    this.assertVariantUniqueness({
      companyId: input.companyId,
      barcode: input.barcode,
      sku: input.sku,
    });

    if (input.priceInCents <= 0) {
      throw new CatalogServiceError('Variant price must be greater than zero.');
    }

    const now = new Date().toISOString();
    const variant: ProductVariantRecord = {
      id: randomUUID(),
      companyId: input.companyId,
      productId: product.id,
      barcode: normalizeOptional(input.barcode),
      sku: normalizeOptional(input.sku),
      color: normalizeOptional(input.color),
      size: normalizeOptional(input.size),
      priceInCents: input.priceInCents,
      promotionalPriceInCents: input.promotionalPriceInCents,
      active: input.active ?? true,
      createdAt: now,
      updatedAt: now,
    };

    this.variantsById.set(variant.id, variant);
    return this.toVariantView(variant);
  }

  updateVariant(input: UpdateVariantInput): ProductVariantView {
    const variant = this.getVariantOrThrow(input.companyId, input.id);
    this.assertVariantUniqueness({
      companyId: input.companyId,
      barcode: input.barcode === undefined ? variant.barcode : input.barcode || undefined,
      sku: input.sku === undefined ? variant.sku : input.sku || undefined,
      ignoreVariantId: variant.id,
    });

    if (input.barcode !== undefined) {
      variant.barcode = input.barcode?.trim() || undefined;
    }
    if (input.sku !== undefined) {
      variant.sku = input.sku?.trim() || undefined;
    }
    if (input.color !== undefined) {
      variant.color = input.color?.trim() || undefined;
    }
    if (input.size !== undefined) {
      variant.size = input.size?.trim() || undefined;
    }
    if (input.priceInCents != null) {
      if (input.priceInCents <= 0) {
        throw new CatalogServiceError('Variant price must be greater than zero.');
      }
      variant.priceInCents = input.priceInCents;
    }
    if (input.promotionalPriceInCents !== undefined) {
      variant.promotionalPriceInCents = input.promotionalPriceInCents || undefined;
    }
    if (input.active != null) {
      variant.active = input.active;
    }

    variant.updatedAt = new Date().toISOString();
    this.variantsById.set(variant.id, variant);
    return this.toVariantView(variant);
  }

  buildSaleSnapshots(companyId: string) {
    return {
      companyId,
      categories: this.listCategories(companyId)
        .filter((category) => category.active)
        .map((category) => ({
          id: category.id,
          name: category.name,
          updatedAt: category.updatedAt,
        })),
      products: this.listProducts(companyId)
        .filter((product) => product.active)
        .map((product) => ({
          id: product.id,
          name: product.name,
          categoryName: product.categoryName,
          isActive: product.active,
          updatedAt: product.updatedAt,
        })),
      variants: this.listVariants(companyId)
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
      cursor: this.latestCursor(companyId),
    };
  }

  private latestCursor(companyId: string): string | null {
    const timestamps = [
      ...this.listCategories(companyId).map((item) => item.updatedAt),
      ...this.listProducts(companyId).map((item) => item.updatedAt),
      ...this.listVariants(companyId).map((item) => item.updatedAt),
    ].sort();

    return timestamps.length === 0 ? null : timestamps[timestamps.length - 1]!;
  }

  private toProductView(product: ProductRecord): ProductView {
    const categoryName = product.categoryId
      ? this.categoriesById.get(product.categoryId)?.name
      : undefined;
    return {
      ...product,
      categoryName,
    };
  }

  private toVariantView(variant: ProductVariantRecord): ProductVariantView {
    const product = this.getProductOrThrow(variant.companyId, variant.productId);
    const categoryName = product.categoryId
      ? this.categoriesById.get(product.categoryId)?.name
      : undefined;
    const parts = [product.name, variant.color, variant.size].filter(Boolean);
    const shortParts = [variant.color, variant.size].filter(Boolean);

    return {
      ...variant,
      productName: product.name,
      categoryName,
      displayName: parts.join(' '),
      shortName: shortParts.join(' ').trim() || product.name,
    };
  }

  private getCategoryOrThrow(companyId: string, id: string): CategoryRecord {
    const category = this.categoriesById.get(id);
    if (!category || category.companyId !== companyId) {
      throw new CatalogServiceError('Category not found.');
    }
    return { ...category };
  }

  private getProductOrThrow(companyId: string, id: string): ProductRecord {
    const product = this.productsById.get(id);
    if (!product || product.companyId !== companyId) {
      throw new CatalogServiceError('Product not found.');
    }
    return { ...product };
  }

  private getVariantOrThrow(companyId: string, id: string): ProductVariantRecord {
    const variant = this.variantsById.get(id);
    if (!variant || variant.companyId !== companyId) {
      throw new CatalogServiceError('Variant not found.');
    }
    return { ...variant };
  }

  private assertCategoryNameAvailable(
    companyId: string,
    name: string,
    ignoreCategoryId?: string,
  ): void {
    const duplicated = [...this.categoriesById.values()].some(
      (category) =>
        category.companyId === companyId &&
        category.id !== ignoreCategoryId &&
        category.name.toLowerCase() === name.toLowerCase(),
    );
    if (duplicated) {
      throw new CatalogServiceError('Category name already exists.');
    }
  }

  private assertVariantUniqueness(input: {
    companyId: string;
    barcode?: string;
    sku?: string;
    ignoreVariantId?: string;
  }): void {
    const barcode = normalizeOptional(input.barcode);
    const sku = normalizeOptional(input.sku);
    const duplicated = [...this.variantsById.values()].some((variant) => {
      if (variant.companyId !== input.companyId || variant.id === input.ignoreVariantId) {
        return false;
      }

      return (
        (barcode != null && variant.barcode === barcode) ||
        (sku != null && variant.sku === sku)
      );
    });

    if (duplicated) {
      throw new CatalogServiceError('Variant barcode or SKU already exists.');
    }
  }

  private seed(): void {
    const companyId = 'company_tatuzin';

    const categorias = [
      {
        id: 'cat_basicos',
        name: 'Basicos',
        active: true,
        timestamp: '2026-04-21T09:00:00.000Z',
      },
      {
        id: 'cat_acessorios',
        name: 'Acessorios',
        active: true,
        timestamp: '2026-04-21T09:05:00.000Z',
      },
    ] satisfies Array<{
      id: string;
      name: string;
      active: boolean;
      timestamp: string;
    }>;

    for (const categoria of categorias) {
      this.categoriesById.set(categoria.id, {
        id: categoria.id,
        companyId,
        name: categoria.name,
        active: categoria.active,
        createdAt: categoria.timestamp,
        updatedAt: categoria.timestamp,
      });
    }

    const produtos = [
      {
        id: 'prod_camiseta_oversized',
        name: 'Camiseta Oversized',
        categoryId: 'cat_basicos',
        active: true,
        timestamp: '2026-04-21T09:01:00.000Z',
      },
      {
        id: 'prod_bolsa_tiracolo',
        name: 'Bolsa Tiracolo',
        categoryId: 'cat_acessorios',
        active: true,
        timestamp: '2026-04-21T09:06:00.000Z',
      },
    ] satisfies Array<{
      id: string;
      name: string;
      categoryId: string;
      active: boolean;
      timestamp: string;
    }>;

    for (const produto of produtos) {
      this.productsById.set(produto.id, {
        id: produto.id,
        companyId,
        name: produto.name,
        categoryId: produto.categoryId,
        active: produto.active,
        createdAt: produto.timestamp,
        updatedAt: produto.timestamp,
      });
    }

    const variantes = [
      {
        id: 'var_camiseta_oversized_preta_m',
        productId: 'prod_camiseta_oversized',
        barcode: '7891000000011',
        sku: 'CAM-OVR-PRT-M',
        color: 'Preta',
        size: 'M',
        priceInCents: 9900,
        promotionalPriceInCents: 8900,
        active: true,
        timestamp: '2026-04-21T09:02:00.000Z',
      },
      {
        id: 'var_bolsa_tiracolo_preta_u',
        productId: 'prod_bolsa_tiracolo',
        barcode: '7891000000097',
        sku: 'BOL-TIR-PRT-U',
        color: 'Preta',
        size: 'U',
        priceInCents: 15900,
        promotionalPriceInCents: undefined,
        active: true,
        timestamp: '2026-04-21T09:07:00.000Z',
      },
    ] satisfies Array<{
      id: string;
      productId: string;
      barcode?: string;
      sku?: string;
      color?: string;
      size?: string;
      priceInCents: number;
      promotionalPriceInCents?: number;
      active: boolean;
      timestamp: string;
    }>;

    for (const variante of variantes) {
      this.variantsById.set(variante.id, {
        id: variante.id,
        companyId,
        productId: variante.productId,
        barcode: variante.barcode,
        sku: variante.sku,
        color: variante.color,
        size: variante.size,
        priceInCents: variante.priceInCents,
        promotionalPriceInCents: variante.promotionalPriceInCents,
        active: variante.active,
        createdAt: variante.timestamp,
        updatedAt: variante.timestamp,
      });
    }
  }
}

function normalizeOptional(value?: string | null): string | undefined {
  const normalized = value?.trim();
  return normalized == null || normalized.length === 0 ? undefined : normalized;
}

export class CatalogServiceError extends Error {}
