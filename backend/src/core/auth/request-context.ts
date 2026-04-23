import type { Request } from 'express';

export type AppRole = 'admin' | 'manager' | 'seller' | 'cashier' | 'crm_user';

export interface AuthContext {
  userId: string;
  email: string;
  name: string;
  companyId: string;
  companyName: string;
  roles: AppRole[];
}

export interface AuthenticatedRequest extends Request {
  auth?: AuthContext;
}
