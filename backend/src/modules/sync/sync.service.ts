import type { AuthContext } from '../../core/auth/request-context.js';
import type { SettlementMethod } from '../sales/receivable-note.js';
import type { ReceivableServiceContract } from '../sales/receivable.contract.js';
import type { SalesServiceContract } from '../sales/sales.contract.js';
import type { SyncCashMovementType } from './sync-cash.service.js';
import { SyncCashServiceError } from './sync-cash.service.js';
import type { SyncCashServiceContract } from './sync-cash.contract.js';
import type { SyncCustomerServiceContract } from './sync-customer.contract.js';
import type { SyncOperationObserver } from './sync-observability.contract.js';
import { SyncUpdatesService } from './sync-updates.service.js';

type OutboxOperationType =
  | 'sale'
  | 'cash_movement'
  | 'quick_customer'
  | 'receivable_note'
  | 'receivable_settlement';

interface SyncOperationInput {
  operationId: string;
  type: OutboxOperationType;
  entityLocalId: string;
  payload: Record<string, unknown>;
}

interface ProcessedOperationResult {
  operationId: string;
  type: OutboxOperationType;
  entityLocalId: string;
  status:
    | 'processed'
    | 'idempotent'
    | 'failed'
    | 'conflict'
    | 'unsupported';
  data?: unknown;
  error?: string;
  conflictType?: string;
}

export class SyncService {
  constructor(
    private readonly salesService: SalesServiceContract,
    private readonly receivableService: ReceivableServiceContract,
    private readonly customerService: SyncCustomerServiceContract,
    private readonly cashService: SyncCashServiceContract,
    private readonly updatesService: SyncUpdatesService,
    private readonly observer?: SyncOperationObserver,
  ) {}

  private readonly processedOperations = new Map<
    string,
    Omit<ProcessedOperationResult, 'status'> & { status: 'processed' | 'unsupported' }
  >();
  private readonly saleRemoteIdByLocalKey = new Map<string, string>();

  async ingestOutbox(
    operations: SyncOperationInput[],
    auth: AuthContext,
  ): Promise<ProcessedOperationResult[]> {
    const results: ProcessedOperationResult[] = [];

    for (const operation of operations) {
      const operationKey = this.toOperationKey(auth.companyId, operation.operationId);
      const existing = this.processedOperations.get(operationKey);
      if (existing) {
        const result: ProcessedOperationResult = {
          ...existing,
          status: 'idempotent',
        };
        await this.recordResult(auth.companyId, operation, result);
        results.push(result);
        continue;
      }

      try {
        const result = await this.processOperation(operation, auth);
        if (result.status === 'processed' || result.status === 'unsupported') {
          this.processedOperations.set(operationKey, {
            operationId: result.operationId,
            type: result.type,
            entityLocalId: result.entityLocalId,
            status: result.status,
            data: result.data,
            error: result.error,
            conflictType: result.conflictType,
          });
        }
        await this.recordResult(auth.companyId, operation, result);
        results.push(result);
      } catch (error) {
        if (error instanceof SyncConflictError) {
          const result: ProcessedOperationResult = {
            operationId: operation.operationId,
            type: operation.type,
            entityLocalId: operation.entityLocalId,
            status: 'conflict',
            error: error.message,
            conflictType: error.conflictType,
          };
          await this.recordResult(auth.companyId, operation, result);
          results.push(result);
          continue;
        }

        const result: ProcessedOperationResult = {
          operationId: operation.operationId,
          type: operation.type,
          entityLocalId: operation.entityLocalId,
          status: 'failed',
          error: error instanceof Error ? error.message : 'Unexpected sync error.',
        };
        await this.recordResult(auth.companyId, operation, result);
        results.push(result);
      }
    }

    return results;
  }

  pullUpdates(input: {
    cursor?: string;
    limit: number;
    auth: AuthContext;
  }) {
    return this.updatesService.pullUpdates({
      companyId: input.auth.companyId,
      cursor: input.cursor,
      limit: input.limit,
    });
  }

  private processOperation(
    operation: SyncOperationInput,
    auth: AuthContext,
  ): Promise<ProcessedOperationResult> | ProcessedOperationResult {
    switch (operation.type) {
      case 'quick_customer':
        return this.processQuickCustomer(operation, auth);
      case 'sale':
        return this.processSale(operation, auth);
      case 'cash_movement':
        return this.processCashMovement(operation, auth);
      case 'receivable_note':
        return this.processReceivableNote(operation, auth);
      case 'receivable_settlement':
        return this.processReceivableSettlement(operation, auth);
      default:
        return {
          operationId: operation.operationId,
          type: operation.type,
          entityLocalId: operation.entityLocalId,
          status: 'unsupported',
        };
    }
  }

  private async processQuickCustomer(
    operation: SyncOperationInput,
    auth: AuthContext,
  ): Promise<ProcessedOperationResult> {
    const payload = operation.payload;
    const result = await this.customerService.upsertQuickCustomer({
      companyId: auth.companyId,
      localId: operation.entityLocalId,
      name: this.readString(payload.name, 'name'),
      phone: this.readString(payload.phone, 'phone'),
      createdAt: this.readOptionalString(payload.createdAt),
    });

    return {
      operationId: operation.operationId,
      type: operation.type,
      entityLocalId: operation.entityLocalId,
      status: result.duplicated ? 'idempotent' : 'processed',
      data: result,
    };
  }

  private async processSale(
    operation: SyncOperationInput,
    auth: AuthContext,
  ): Promise<ProcessedOperationResult> {
    const payload = operation.payload;
    const customerLocalId = this.readOptionalString(payload.customerLocalId);
    const customerId = await this.customerService.resolveRemoteCustomerId(
      auth.companyId,
      customerLocalId,
    );

    if (customerLocalId && !customerId) {
      throw new SyncConflictError(
        'quick_customer_missing',
        'Cliente rapido ainda nao foi sincronizado no backend.',
      );
    }

    const result = await this.salesService.createSale({
      operationId: operation.operationId,
      companyId: auth.companyId,
      userId: auth.userId,
      customerId,
      subtotalInCents: this.readInt(payload.subtotalInCents, 'subtotalInCents'),
      discountInCents: this.readInt(payload.discountInCents, 'discountInCents'),
      totalInCents: this.readInt(payload.totalInCents, 'totalInCents'),
      createdAt: this.readOptionalString(payload.createdAt),
      items: this.readItems(payload.items),
      payments: this.readPayments(payload.payments),
    });

    this.saleRemoteIdByLocalKey.set(
      this.toLocalEntityKey(auth.companyId, operation.entityLocalId),
      result.sale.id,
    );

    return {
      operationId: operation.operationId,
      type: operation.type,
      entityLocalId: operation.entityLocalId,
      status: result.duplicated ? 'idempotent' : 'processed',
      data: result,
    };
  }

  private async processCashMovement(
    operation: SyncOperationInput,
    auth: AuthContext,
  ): Promise<ProcessedOperationResult> {
    const payload = operation.payload;
    try {
      const movement = await this.cashService.createMovement({
        companyId: auth.companyId,
        userId: auth.userId,
        cashSessionLocalId: this.readString(
          payload.cashSessionLocalId,
          'cashSessionLocalId',
        ),
        saleLocalId: this.readOptionalString(payload.saleLocalId),
        type: this.readCashMovementType(payload.type),
        amountInCents: this.readInt(payload.amountInCents, 'amountInCents'),
        notes: this.readOptionalString(payload.notes),
        createdAt:
          this.readOptionalString(payload.createdAt) ??
          this.readOptionalString(payload.openedAt),
      });

      return {
        operationId: operation.operationId,
        type: operation.type,
        entityLocalId: operation.entityLocalId,
        status: 'processed',
        data: movement,
      };
    } catch (error) {
      if (error instanceof SyncCashServiceError) {
        throw new SyncConflictError('cash_movement_invalid', error.message);
      }
      throw error;
    }
  }

  private async processReceivableNote(
    operation: SyncOperationInput,
    auth: AuthContext,
  ): Promise<ProcessedOperationResult> {
    const payload = operation.payload;
    const saleLocalId = this.readString(payload.saleLocalId, 'saleLocalId');
    const saleId = this.saleRemoteIdByLocalKey.get(
      this.toLocalEntityKey(auth.companyId, saleLocalId),
    );

    if (!saleId) {
      throw new SyncConflictError(
        'sale_missing',
        'Venda remota ainda nao foi confirmada para esta nota.',
      );
    }

    const customerLocalId = this.readOptionalString(payload.customerLocalId);
    const customerId = await this.customerService.resolveRemoteCustomerId(
      auth.companyId,
      customerLocalId,
    );

    if (customerLocalId && !customerId) {
      throw new SyncConflictError(
        'quick_customer_missing',
        'Cliente da nota ainda nao foi sincronizado no backend.',
      );
    }

    const result = await this.receivableService.issueFromSale({
      companyId: auth.companyId,
      saleId,
      customerId,
      originalAmountInCents: this.readInt(
        payload.originalAmountInCents,
        'originalAmountInCents',
      ),
      dueDate: this.readString(payload.dueDate, 'dueDate'),
      issueDate: this.readOptionalString(payload.createdAt),
      notes: this.readOptionalString(payload.notes),
      createdByUserId: auth.userId,
    });

    return {
      operationId: operation.operationId,
      type: operation.type,
      entityLocalId: operation.entityLocalId,
      status: result.duplicated ? 'idempotent' : 'processed',
      data: result,
    };
  }

  private async processReceivableSettlement(
    operation: SyncOperationInput,
    auth: AuthContext,
  ): Promise<ProcessedOperationResult> {
    const payload = operation.payload;
    const paymentTermRemoteId =
      this.readOptionalString(payload.paymentTermRemoteId) ??
      this.readOptionalString(payload.receivableNoteId);
    const saleLocalId = this.readOptionalString(payload.saleLocalId);
    const saleId =
      saleLocalId == null
        ? undefined
        : this.saleRemoteIdByLocalKey.get(
            this.toLocalEntityKey(auth.companyId, saleLocalId),
          );
    const note =
      paymentTermRemoteId == null && saleId != null
        ? await this.receivableService.findBySale(auth.companyId, saleId)
        : undefined;
    const noteId = paymentTermRemoteId ?? note?.id;

    if (!noteId) {
      throw new SyncConflictError(
        'receivable_note_missing',
        'Nota remota ainda nao foi confirmada para esta baixa.',
      );
    }

    const result = await this.receivableService.registerSettlement({
      companyId: auth.companyId,
      noteId,
      operationId: operation.operationId,
      amountInCents: this.readInt(payload.amountInCents, 'amountInCents'),
      settlementMethod: this.readSettlementMethod(payload.settlementMethod),
      settledAt:
        this.readOptionalString(payload.paidAt) ??
        this.readOptionalString(payload.settledAt),
      createdByUserId: auth.userId,
    });

    return {
      operationId: operation.operationId,
      type: operation.type,
      entityLocalId: operation.entityLocalId,
      status: result.duplicated ? 'idempotent' : 'processed',
      data: result,
    };
  }

  private readItems(value: unknown) {
    if (!Array.isArray(value) || value.length === 0) {
      throw new SyncConflictError('sale_items_invalid', 'Venda sem itens validos.');
    }

    return value.map((entry) => {
      const item = entry as Record<string, unknown>;
      return {
        variantId: this.readOptionalString(item.variantRemoteId),
        displayName: this.readString(item.displayName, 'displayName'),
        quantity: this.readInt(item.quantity, 'quantity'),
        unitPriceInCents: this.readInt(item.unitPriceInCents, 'unitPriceInCents'),
        totalPriceInCents: this.readInt(
          item.totalPriceInCents,
          'totalPriceInCents',
        ),
      };
    });
  }

  private readPayments(value: unknown) {
    if (!Array.isArray(value) || value.length === 0) {
      throw new SyncConflictError(
        'sale_payments_invalid',
        'Venda sem pagamentos validos.',
      );
    }

    return value.map((entry) => {
      const payment = entry as Record<string, unknown>;
      return {
        method: this.readPaymentMethod(payment.method),
        amountInCents: this.readInt(payment.amountInCents, 'amountInCents'),
        dueDate: this.readOptionalString(payment.dueDate),
        notes: this.readOptionalString(payment.notes),
      };
    });
  }

  private readPaymentMethod(value: unknown): 'cash' | 'pix' | 'note' {
    if (value === 'cash' || value === 'pix' || value === 'note') {
      return value;
    }

    throw new SyncConflictError(
      'payment_method_invalid',
      'Metodo de pagamento nao suportado no sync.',
    );
  }

  private readCashMovementType(value: unknown): SyncCashMovementType {
    if (
      value === 'opening' ||
      value === 'sale_cash' ||
      value === 'sale_pix' ||
      value === 'sale_note' ||
      value === 'supply' ||
      value === 'withdrawal' ||
      value === 'receivable_settlement_cash' ||
      value === 'receivable_settlement_pix' ||
      value === 'closing'
    ) {
      return value;
    }

    throw new SyncConflictError(
      'cash_movement_type_invalid',
      'Tipo de movimento de caixa nao suportado.',
    );
  }

  private readSettlementMethod(value: unknown): SettlementMethod {
    if (
      value === 'cash' ||
      value === 'pix' ||
      value === 'bank_transfer' ||
      value === 'mixed'
    ) {
      return value;
    }

    throw new SyncConflictError(
      'settlement_method_invalid',
      'Metodo de baixa de nota nao suportado.',
    );
  }

  private readString(value: unknown, field: string): string {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }

    throw new SyncConflictError(
      'payload_invalid',
      `Campo obrigatorio ausente ou invalido: ${field}.`,
    );
  }

  private readOptionalString(value: unknown): string | undefined {
    return typeof value === 'string' && value.trim().length > 0
      ? value.trim()
      : undefined;
  }

  private readInt(value: unknown, field: string): number {
    if (typeof value === 'number' && Number.isInteger(value)) {
      return value;
    }

    throw new SyncConflictError(
      'payload_invalid',
      `Campo numerico invalido: ${field}.`,
    );
  }

  private toOperationKey(companyId: string, operationId: string): string {
    return `${companyId}:${operationId}`;
  }

  private toLocalEntityKey(companyId: string, localId: string): string {
    return `${companyId}:${localId}`;
  }

  private async recordResult(
    companyId: string,
    operation: SyncOperationInput,
    result: ProcessedOperationResult,
  ): Promise<void> {
    await this.observer?.recordResult({
      companyId,
      operation,
      result,
    });
  }
}

class SyncConflictError extends Error {
  constructor(
    readonly conflictType: string,
    message: string,
  ) {
    super(message);
  }
}
