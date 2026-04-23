import type { MaybePromise } from '../catalog/catalog.contract.js';
import type { DeviceRecord, DeviceRegistrationInput } from './device.service.js';

export interface DeviceServiceContract {
  register(input: DeviceRegistrationInput): MaybePromise<DeviceRecord>;
}
