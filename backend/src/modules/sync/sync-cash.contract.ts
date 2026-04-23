import type { MaybePromise } from '../catalog/catalog.contract.js';
import type {
  CloseCashSessionInput,
  CreateCashMovementInput,
  OpenCashSessionInput,
  SyncedCashMovementRecord,
  SyncedCashSessionSummary,
} from './sync-cash.service.js';

export interface SyncCashServiceContract {
  openSession(input: OpenCashSessionInput): MaybePromise<SyncedCashSessionSummary>;
  closeSession(
    input: CloseCashSessionInput,
  ): MaybePromise<SyncedCashSessionSummary>;
  createMovement(
    input: CreateCashMovementInput,
  ): MaybePromise<SyncedCashMovementRecord>;
  listSessions(companyId: string): MaybePromise<SyncedCashSessionSummary[]>;
  listMovementsBySession(
    companyId: string,
    cashSessionLocalId: string,
  ): MaybePromise<SyncedCashMovementRecord[]>;
  getSession(
    companyId: string,
    cashSessionLocalId: string,
  ): MaybePromise<SyncedCashSessionSummary>;
}
