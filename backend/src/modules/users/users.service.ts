import bcrypt from 'bcryptjs';
import { randomUUID } from 'node:crypto';

import type { AppRole } from '../../core/auth/request-context.js';
import { demoUsers } from '../auth/demo-users.js';

export interface UserView {
  id: string;
  companyId: string;
  companyName: string;
  name: string;
  email: string;
  roles: AppRole[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateUserInput {
  companyId: string;
  companyName: string;
  name: string;
  email: string;
  password: string;
  roles: AppRole[];
}

export interface UpdateUserInput {
  companyId: string;
  id: string;
  name?: string;
  email?: string;
  password?: string;
  roles?: AppRole[];
}

type InternalUser = UserView & {
  passwordHash: string;
};

export class UsersService {
  private readonly users = new Map<string, InternalUser>();

  constructor() {
    for (const user of demoUsers) {
      const timestamp = new Date().toISOString();
      this.users.set(user.userId, {
        id: user.userId,
        companyId: user.companyId,
        companyName: user.companyName,
        name: user.name,
        email: user.email,
        roles: [...user.roles],
        passwordHash: user.passwordHash,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
    }
  }

  listUsers(companyId: string): UserView[] {
    return [...this.users.values()]
      .filter((user) => user.companyId === companyId)
      .sort((left, right) => left.name.localeCompare(right.name))
      .map(toUserView);
  }

  async createUser(input: CreateUserInput): Promise<UserView> {
    const email = normalizeEmail(input.email);
    this.assertEmailAvailable(email);
    const roles = normalizeRoles(input.roles);
    const now = new Date().toISOString();
    const user: InternalUser = {
      id: randomUUID(),
      companyId: input.companyId,
      companyName: input.companyName,
      name: normalizeRequired(input.name, 'User name is required.'),
      email,
      roles,
      passwordHash: await bcrypt.hash(input.password, 10),
      createdAt: now,
      updatedAt: now,
    };
    this.users.set(user.id, user);
    return toUserView(user);
  }

  async updateUser(input: UpdateUserInput): Promise<UserView> {
    const existing = this.users.get(input.id);
    if (existing == null || existing.companyId !== input.companyId) {
      throw new UsersServiceError('User not found.');
    }

    const nextEmail =
      input.email == null ? existing.email : normalizeEmail(input.email);
    if (nextEmail !== existing.email) {
      this.assertEmailAvailable(nextEmail, existing.id);
    }

    const updated: InternalUser = {
      ...existing,
      name:
        input.name == null
          ? existing.name
          : normalizeRequired(input.name, 'User name is required.'),
      email: nextEmail,
      roles: input.roles == null ? existing.roles : normalizeRoles(input.roles),
      passwordHash:
        input.password == null
          ? existing.passwordHash
          : await bcrypt.hash(input.password, 10),
      updatedAt: new Date().toISOString(),
    };
    this.users.set(updated.id, updated);
    return toUserView(updated);
  }

  private assertEmailAvailable(email: string, ignoreUserId?: string): void {
    const duplicate = [...this.users.values()].find(
      (user) => user.email === email && user.id !== ignoreUserId,
    );
    if (duplicate != null) {
      throw new UsersServiceError('User email already exists.');
    }
  }
}

export class UsersServiceError extends Error {}

function toUserView(user: InternalUser): UserView {
  return {
    id: user.id,
    companyId: user.companyId,
    companyName: user.companyName,
    name: user.name,
    email: user.email,
    roles: [...user.roles],
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

function normalizeRequired(value: string, message: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new UsersServiceError(message);
  }
  return normalized;
}

function normalizeEmail(value: string): string {
  return normalizeRequired(value, 'User email is required.').toLowerCase();
}

function normalizeRoles(roles: AppRole[]): AppRole[] {
  const uniqueRoles = [...new Set(roles)];
  if (uniqueRoles.length === 0) {
    throw new UsersServiceError('At least one role is required.');
  }
  return uniqueRoles;
}
