import { randomUUID } from 'node:crypto';

export interface DeviceRegistrationInput {
  companyId: string;
  userId: string;
  deviceId: string;
  platform: string;
  appVersion?: string;
}

export interface DeviceRecord extends DeviceRegistrationInput {
  id: string;
  createdAt: string;
  updatedAt: string;
}

export class DeviceService {
  private readonly devicesByKey = new Map<string, DeviceRecord>();

  register(input: DeviceRegistrationInput): DeviceRecord {
    const key = `${input.companyId}:${input.deviceId}`;
    const existing = this.devicesByKey.get(key);
    const now = new Date().toISOString();

    if (existing) {
      const updated: DeviceRecord = {
        ...existing,
        platform: input.platform,
        appVersion: input.appVersion,
        updatedAt: now,
      };
      this.devicesByKey.set(key, updated);
      return updated;
    }

    const created: DeviceRecord = {
      id: randomUUID(),
      ...input,
      createdAt: now,
      updatedAt: now,
    };

    this.devicesByKey.set(key, created);
    return created;
  }
}
