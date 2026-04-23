import type { MaybePromise } from '../catalog/catalog.contract.js';
import type { AuthSession } from './auth.service.js';

export interface AuthServiceContract {
  login(email: string, password: string): MaybePromise<AuthSession>;
  refresh(refreshToken: string): MaybePromise<AuthSession>;
  logout(refreshToken: string): MaybePromise<void>;
}
