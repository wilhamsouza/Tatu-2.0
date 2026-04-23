import type { MaybePromise } from '../catalog/catalog.contract.js';

export type SyncOperationResultStatus =
  | 'processed'
  | 'idempotent'
  | 'failed'
  | 'conflict'
  | 'unsupported';

export interface SyncObservedOperation {
  operationId: string;
  type: string;
  entityLocalId: string;
  payload: Record<string, unknown>;
}

export interface SyncObservedResult {
  operationId: string;
  type: string;
  entityLocalId: string;
  status: SyncOperationResultStatus;
  data?: unknown;
  error?: string;
  conflictType?: string;
}

export interface SyncOperationObserver {
  recordResult(input: {
    companyId: string;
    operation: SyncObservedOperation;
    result: SyncObservedResult;
  }): MaybePromise<void>;
}
