import type {
  CategoryView,
  CreateCategoryInput,
  CreateProductInput,
  CreateVariantInput,
  ProductVariantView,
  ProductView,
  UpdateCategoryInput,
  UpdateProductInput,
  UpdateVariantInput,
} from './catalog.service.js';

export type MaybePromise<T> = T | Promise<T>;

export interface CatalogSnapshotsView {
  companyId: string;
  categories: Array<{
    id: string;
    name: string;
    updatedAt: string;
  }>;
  products: Array<{
    id: string;
    name: string;
    categoryName?: string;
    isActive: boolean;
    updatedAt: string;
  }>;
  variants: Array<{
    id: string;
    productId: string;
    barcode?: string;
    sku?: string;
    displayName: string;
    shortName: string;
    color?: string;
    size?: string;
    categoryName?: string;
    priceInCents: number;
    promotionalPriceInCents?: number;
    imageUrl: null;
    isActiveForSale: boolean;
    updatedAt: string;
  }>;
  cursor: string | null;
}

export interface CatalogServiceContract {
  listCategories(companyId: string): MaybePromise<CategoryView[]>;
  createCategory(input: CreateCategoryInput): MaybePromise<CategoryView>;
  updateCategory(input: UpdateCategoryInput): MaybePromise<CategoryView>;
  listProducts(companyId: string): MaybePromise<ProductView[]>;
  createProduct(input: CreateProductInput): MaybePromise<ProductView>;
  updateProduct(input: UpdateProductInput): MaybePromise<ProductView>;
  listVariants(companyId: string): MaybePromise<ProductVariantView[]>;
  getVariant(
    companyId: string,
    id: string,
  ): MaybePromise<ProductVariantView>;
  createVariant(input: CreateVariantInput): MaybePromise<ProductVariantView>;
  updateVariant(input: UpdateVariantInput): MaybePromise<ProductVariantView>;
  buildSaleSnapshots(companyId: string): MaybePromise<CatalogSnapshotsView>;
}
