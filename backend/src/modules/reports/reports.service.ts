import type { CatalogServiceContract } from "../catalog/catalog.contract.js";
import type { ProductVariantView } from "../catalog/catalog.service.js";
import type { ReceivableStatus } from "../sales/receivable-note.js";
import { resolveReceivableStatus } from "../sales/receivable-note.js";
import type { ReceivableServiceContract } from "../sales/receivable.contract.js";
import type { SalesServiceContract } from "../sales/sales.contract.js";
import type { SalePaymentMethod, SaleRecord } from "../sales/sales.service.js";

export type ReportPeriod = "daily" | "weekly" | "monthly";

export interface ReportPaymentBreakdownItem {
  method: SalePaymentMethod;
  amountInCents: number;
  transactionCount: number;
}

export interface ReportRankingItem {
  id: string;
  label: string;
  unitsSold: number;
  revenueInCents: number;
  salesCount: number;
}

export interface PeriodReportView {
  period: ReportPeriod;
  label: string;
  startsAt: string;
  endsAt: string;
  salesCount: number;
  itemsSold: number;
  grossRevenueInCents: number;
  discountInCents: number;
  netRevenueInCents: number;
  averageTicketInCents: number;
  liquidatedRevenueInCents: number;
  noteRevenueInCents: number;
  openReceivablesInCents: number;
  overdueReceivablesInCents: number;
  openReceivablesCount: number;
  overdueReceivablesCount: number;
  paymentBreakdown: ReportPaymentBreakdownItem[];
  topProducts: ReportRankingItem[];
  topVariants: ReportRankingItem[];
}

export interface ReportsDashboardView {
  generatedAt: string;
  referenceDate: string;
  reports: Record<ReportPeriod, PeriodReportView>;
}

export class ReportsService {
  constructor(
    private readonly catalogService: CatalogServiceContract,
    private readonly salesService: SalesServiceContract,
    private readonly receivableService: ReceivableServiceContract,
  ) {}

  async buildDashboard(input: {
    companyId: string;
    referenceDate?: string;
    rankingLimit?: number;
  }): Promise<ReportsDashboardView> {
    const referenceDate = this.parseReferenceDate(input.referenceDate);
    const rankingLimit = clampRankingLimit(input.rankingLimit ?? 5);
    const variants = await this.catalogService.listVariants(input.companyId);
    const variantById = new Map(
      variants.map((variant) => [variant.id, variant]),
    );
    const [sales, notes] = await Promise.all([
      this.salesService.listSales(input.companyId),
      this.receivableService.listNotes(input.companyId),
    ]);
    const receivables = notes.map((note) => {
        const effectiveStatus = resolveReceivableStatus({
          dueDate: note.dueDate,
          outstandingAmountInCents: note.outstandingAmountInCents,
          paidAmountInCents: note.paidAmountInCents,
          now: referenceDate.toISOString(),
        });

        return {
          ...note,
          effectiveStatus,
        };
      });

    return {
      generatedAt: new Date().toISOString(),
      referenceDate: referenceDate.toISOString(),
      reports: {
        daily: this.buildPeriodReport({
          period: "daily",
          referenceDate,
          sales,
          receivables,
          variantById,
          rankingLimit,
        }),
        weekly: this.buildPeriodReport({
          period: "weekly",
          referenceDate,
          sales,
          receivables,
          variantById,
          rankingLimit,
        }),
        monthly: this.buildPeriodReport({
          period: "monthly",
          referenceDate,
          sales,
          receivables,
          variantById,
          rankingLimit,
        }),
      },
    };
  }

  private buildPeriodReport(input: {
    period: ReportPeriod;
    referenceDate: Date;
    sales: SaleRecord[];
    receivables: Array<{
      dueDate: string;
      outstandingAmountInCents: number;
      effectiveStatus: ReceivableStatus;
    }>;
    variantById: Map<string, ProductVariantView>;
    rankingLimit: number;
  }): PeriodReportView {
    const window = resolvePeriodWindow(input.period, input.referenceDate);
    const periodSales = input.sales.filter((sale) =>
      isWithinRange(sale.createdAt, window.startsAt, window.endsAt),
    );

    const paymentBreakdown = createPaymentBreakdown();
    let itemsSold = 0;
    let grossRevenueInCents = 0;
    let discountInCents = 0;
    let netRevenueInCents = 0;
    let liquidatedRevenueInCents = 0;
    let noteRevenueInCents = 0;

    const productRanking = new Map<string, MutableRankingEntry>();
    const variantRanking = new Map<string, MutableRankingEntry>();

    for (const sale of periodSales) {
      grossRevenueInCents += sale.subtotalInCents;
      discountInCents += sale.discountInCents;
      netRevenueInCents += sale.totalInCents;

      for (const payment of sale.payments) {
        const breakdown = paymentBreakdown.get(payment.method)!;
        breakdown.amountInCents += payment.amountInCents;
        breakdown.transactionCount += 1;

        if (payment.method === "note") {
          noteRevenueInCents += payment.amountInCents;
        } else {
          liquidatedRevenueInCents += payment.amountInCents;
        }
      }

      for (const item of sale.items) {
        itemsSold += item.quantity;

        const variant =
          item.variantId == null
            ? undefined
            : input.variantById.get(item.variantId);
        const variantId = variant?.id ?? `variant:${item.displayName}`;
        const variantLabel = variant?.displayName ?? item.displayName;
        const productId = variant?.productId ?? `product:${item.displayName}`;
        const productLabel = variant?.productName ?? item.displayName;

        upsertRankingEntry(variantRanking, {
          id: variantId,
          label: variantLabel,
          quantity: item.quantity,
          revenueInCents: item.totalPriceInCents,
          saleId: sale.id,
        });
        upsertRankingEntry(productRanking, {
          id: productId,
          label: productLabel,
          quantity: item.quantity,
          revenueInCents: item.totalPriceInCents,
          saleId: sale.id,
        });
      }
    }

    const openReceivables = input.receivables.filter(
      (note) =>
        note.effectiveStatus === "pending" ||
        note.effectiveStatus === "partially_paid" ||
        note.effectiveStatus === "overdue",
    );
    const overdueReceivables = openReceivables.filter(
      (note) => note.effectiveStatus === "overdue",
    );

    return {
      period: input.period,
      label: reportLabel(input.period),
      startsAt: window.startsAt.toISOString(),
      endsAt: window.endsAt.toISOString(),
      salesCount: periodSales.length,
      itemsSold,
      grossRevenueInCents,
      discountInCents,
      netRevenueInCents,
      averageTicketInCents:
        periodSales.length === 0
          ? 0
          : Math.round(netRevenueInCents / periodSales.length),
      liquidatedRevenueInCents,
      noteRevenueInCents,
      openReceivablesInCents: openReceivables.reduce(
        (sum, note) => sum + note.outstandingAmountInCents,
        0,
      ),
      overdueReceivablesInCents: overdueReceivables.reduce(
        (sum, note) => sum + note.outstandingAmountInCents,
        0,
      ),
      openReceivablesCount: openReceivables.length,
      overdueReceivablesCount: overdueReceivables.length,
      paymentBreakdown: [...paymentBreakdown.values()],
      topProducts: toRankingList(productRanking, input.rankingLimit),
      topVariants: toRankingList(variantRanking, input.rankingLimit),
    };
  }

  private parseReferenceDate(rawValue?: string): Date {
    if (rawValue == null || rawValue.trim().length === 0) {
      return new Date();
    }

    const parsed = new Date(rawValue);
    if (Number.isNaN(parsed.getTime())) {
      throw new ReportsServiceError(
        "Invalid referenceDate provided for reports.",
      );
    }

    return parsed;
  }
}

function createPaymentBreakdown(): Map<
  SalePaymentMethod,
  ReportPaymentBreakdownItem
> {
  return new Map<SalePaymentMethod, ReportPaymentBreakdownItem>([
    ["cash", { method: "cash", amountInCents: 0, transactionCount: 0 }],
    ["pix", { method: "pix", amountInCents: 0, transactionCount: 0 }],
    ["note", { method: "note", amountInCents: 0, transactionCount: 0 }],
  ]);
}

function upsertRankingEntry(
  target: Map<string, MutableRankingEntry>,
  input: {
    id: string;
    label: string;
    quantity: number;
    revenueInCents: number;
    saleId: string;
  },
): void {
  const current = target.get(input.id) ?? {
    id: input.id,
    label: input.label,
    unitsSold: 0,
    revenueInCents: 0,
    saleIds: new Set<string>(),
  };

  current.unitsSold += input.quantity;
  current.revenueInCents += input.revenueInCents;
  current.saleIds.add(input.saleId);
  target.set(input.id, current);
}

function toRankingList(
  source: Map<string, MutableRankingEntry>,
  limit: number,
): ReportRankingItem[] {
  return [...source.values()]
    .map((entry) => ({
      id: entry.id,
      label: entry.label,
      unitsSold: entry.unitsSold,
      revenueInCents: entry.revenueInCents,
      salesCount: entry.saleIds.size,
    }))
    .sort((left, right) => {
      if (right.revenueInCents !== left.revenueInCents) {
        return right.revenueInCents - left.revenueInCents;
      }
      if (right.unitsSold !== left.unitsSold) {
        return right.unitsSold - left.unitsSold;
      }
      return left.label.localeCompare(right.label);
    })
    .slice(0, limit);
}

function resolvePeriodWindow(
  period: ReportPeriod,
  referenceDate: Date,
): {
  startsAt: Date;
  endsAt: Date;
} {
  const utcReference = new Date(
    Date.UTC(
      referenceDate.getUTCFullYear(),
      referenceDate.getUTCMonth(),
      referenceDate.getUTCDate(),
    ),
  );

  switch (period) {
    case "daily":
      return {
        startsAt: utcReference,
        endsAt: addDays(utcReference, 1),
      };
    case "weekly": {
      const dayOfWeek = utcReference.getUTCDay();
      const offsetFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
      const startsAt = addDays(utcReference, -offsetFromMonday);
      return {
        startsAt,
        endsAt: addDays(startsAt, 7),
      };
    }
    case "monthly": {
      const startsAt = new Date(
        Date.UTC(
          referenceDate.getUTCFullYear(),
          referenceDate.getUTCMonth(),
          1,
        ),
      );
      return {
        startsAt,
        endsAt: new Date(
          Date.UTC(
            referenceDate.getUTCFullYear(),
            referenceDate.getUTCMonth() + 1,
            1,
          ),
        ),
      };
    }
  }
}

function isWithinRange(value: string, startsAt: Date, endsAt: Date): boolean {
  const timestamp = new Date(value).getTime();
  return timestamp >= startsAt.getTime() && timestamp < endsAt.getTime();
}

function addDays(value: Date, days: number): Date {
  return new Date(value.getTime() + days * 24 * 60 * 60 * 1000);
}

function reportLabel(period: ReportPeriod): string {
  switch (period) {
    case "daily":
      return "Diario";
    case "weekly":
      return "Semanal";
    case "monthly":
      return "Mensal";
  }
}

function clampRankingLimit(limit: number): number {
  return Math.max(1, Math.min(limit, 10));
}

interface MutableRankingEntry {
  id: string;
  label: string;
  unitsSold: number;
  revenueInCents: number;
  saleIds: Set<string>;
}

export class ReportsServiceError extends Error {}
