import type { MaybePromise } from '../catalog/catalog.contract.js';
import type { ReportsDashboardView } from './reports.service.js';

export interface ReportsServiceContract {
  buildDashboard(input: {
    companyId: string;
    referenceDate?: string;
    rankingLimit?: number;
  }): MaybePromise<ReportsDashboardView>;
}
