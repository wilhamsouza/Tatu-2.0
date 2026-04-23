import {
  SyncOperationStatus as PrismaSyncOperationStatus,
  type PrismaClient,
} from '@prisma/client';

import type {
  SyncObservedResult,
  SyncOperationObserver,
} from './sync-observability.contract.js';

export class PrismaSyncObservabilityService implements SyncOperationObserver {
  constructor(private readonly prisma: PrismaClient) {}

  async recordResult(input: Parameters<SyncOperationObserver['recordResult']>[0]) {
    await this.ensureCompany(input.companyId);
    await this.prisma.syncOperationLog.upsert({
      where: {
        companyId_operationId: {
          companyId: input.companyId,
          operationId: input.operation.operationId,
        },
      },
      create: {
        companyId: input.companyId,
        operationId: input.operation.operationId,
        type: input.operation.type,
        status: toPrismaSyncStatus(input.result),
        payloadJson: JSON.stringify(input.operation.payload),
        lastError: input.result.error,
      },
      update: {
        type: input.operation.type,
        status: toPrismaSyncStatus(input.result),
        payloadJson: JSON.stringify(input.operation.payload),
        lastError: input.result.error,
      },
    });

    if (input.result.status === 'conflict') {
      await this.upsertConflict(input);
    }
  }

  private async upsertConflict(
    input: Parameters<SyncOperationObserver['recordResult']>[0],
  ): Promise<void> {
    const existing = await this.prisma.syncConflict.findFirst({
      where: {
        companyId: input.companyId,
        operationId: input.operation.operationId,
      },
    });

    const data = {
      companyId: input.companyId,
      operationId: input.operation.operationId,
      type: input.result.conflictType ?? input.operation.type,
      message: input.result.error ?? 'Sync conflict.',
      payloadJson: JSON.stringify(input.operation.payload),
    };

    if (existing == null) {
      await this.prisma.syncConflict.create({ data });
      return;
    }

    await this.prisma.syncConflict.update({
      where: { id: existing.id },
      data,
    });
  }

  private async ensureCompany(companyId: string): Promise<void> {
    await this.prisma.company.upsert({
      where: { id: companyId },
      create: { id: companyId, name: 'Tatuzin Demo' },
      update: {},
    });
  }
}

function toPrismaSyncStatus(
  result: SyncObservedResult,
): PrismaSyncOperationStatus {
  switch (result.status) {
    case 'conflict':
      return PrismaSyncOperationStatus.CONFLICT;
    case 'failed':
    case 'unsupported':
      return PrismaSyncOperationStatus.FAILED;
    default:
      return PrismaSyncOperationStatus.SYNCED;
  }
}
