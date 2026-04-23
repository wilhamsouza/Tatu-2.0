import bcrypt from 'bcryptjs';

import type { AppRole, AuthContext } from '../../core/auth/request-context.js';

const company = {
  companyId: 'company_tatuzin',
  companyName: 'Tatuzin Moda',
};

const passwordHash = bcrypt.hashSync('tatuzin123', 10);

export interface DemoUser extends AuthContext {
  passwordHash: string;
}

function user(
  userId: string,
  email: string,
  name: string,
  roles: AppRole[],
): DemoUser {
  return {
    userId,
    email,
    name,
    roles,
    ...company,
    passwordHash,
  };
}

export const demoUsers: DemoUser[] = [
  user('user_admin', 'admin@tatuzin.app', 'Tatuzin Admin', ['admin']),
  user('user_manager', 'manager@tatuzin.app', 'Gerente Tatuzin', ['manager']),
  user('user_seller', 'seller@tatuzin.app', 'Vendedor Tatuzin', ['seller']),
  user('user_cashier', 'cashier@tatuzin.app', 'Operador de Caixa', ['cashier']),
  user('user_crm', 'crm@tatuzin.app', 'CRM Tatuzin', ['crm_user']),
];
