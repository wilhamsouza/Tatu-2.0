import type { PrismaClient } from '@prisma/client';

import { seedDemoIdentity } from '../auth/prisma-identity.seed.js';
import type { DeviceServiceContract } from './device.contract.js';
import type {
  DeviceRecord,
  DeviceRegistrationInput,
} from './device.service.js';

export class PrismaDeviceService implements DeviceServiceContract {
  private seedPromise?: Promise<void>;

  constructor(private readonly prisma: PrismaClient) {}

  async register(input: DeviceRegistrationInput): Promise<DeviceRecord> {
    await this.ensureSeeded();

    const user = await this.prisma.user.findUnique({
      where: { id: input.userId },
    });
    if (user == null) {
      throw new Error('User not found.');
    }

    const device = await this.prisma.device.upsert({
      where: {
        companyId_deviceIdentifier: {
          companyId: input.companyId,
          deviceIdentifier: input.deviceId,
        },
      },
      create: {
        companyId: input.companyId,
        userId: input.userId,
        deviceIdentifier: input.deviceId,
        platform: input.platform,
        appVersion: input.appVersion,
      },
      update: {
        userId: input.userId,
        platform: input.platform,
        appVersion: input.appVersion,
      },
    });

    return {
      id: device.id,
      companyId: device.companyId,
      userId: device.userId,
      deviceId: device.deviceIdentifier,
      platform: device.platform,
      appVersion: device.appVersion ?? undefined,
      createdAt: device.createdAt.toISOString(),
      updatedAt: device.updatedAt.toISOString(),
    };
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= seedDemoIdentity(this.prisma);
    return this.seedPromise;
  }
}
