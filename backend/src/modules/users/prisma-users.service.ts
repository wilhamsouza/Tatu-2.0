import { AppRole as PrismaAppRole, type PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

import type { AppRole } from '../../core/auth/request-context.js';
import {
  fromPrismaAppRole,
  seedDemoIdentity,
  toPrismaAppRole,
} from '../auth/prisma-identity.seed.js';
import type { UsersServiceContract } from './users.contract.js';
import {
  UsersServiceError,
  type CreateUserInput,
  type UpdateUserInput,
  type UserView,
} from './users.service.js';

type UserWithMemberships = {
  id: string;
  name: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
  memberships: Array<{
    role: PrismaAppRole;
    company: {
      id: string;
      name: string;
    };
  }>;
};

export class PrismaUsersService implements UsersServiceContract {
  private seedPromise?: Promise<void>;

  constructor(private readonly prisma: PrismaClient) {}

  async listUsers(companyId: string): Promise<UserView[]> {
    await this.ensureSeeded();
    const users = await this.prisma.user.findMany({
      where: {
        memberships: { some: { companyId } },
      },
      include: {
        memberships: {
          where: { companyId },
          include: { company: true },
          orderBy: { role: 'asc' },
        },
      },
      orderBy: { name: 'asc' },
    });

    return users.map((user) => toUserView(user as UserWithMemberships));
  }

  async createUser(input: CreateUserInput): Promise<UserView> {
    await this.ensureSeeded();
    const email = normalizeEmail(input.email);
    await this.assertEmailAvailable(email);
    const roles = normalizeRoles(input.roles);

    const user = await this.prisma.user.create({
      data: {
        name: normalizeRequired(input.name, 'User name is required.'),
        email,
        passwordHash: await bcrypt.hash(input.password, 10),
        memberships: {
          create: roles.map((role) => ({
            companyId: input.companyId,
            role: toPrismaAppRole(role),
          })),
        },
      },
      include: {
        memberships: {
          where: { companyId: input.companyId },
          include: { company: true },
          orderBy: { role: 'asc' },
        },
      },
    });

    return toUserView(user as UserWithMemberships);
  }

  async updateUser(input: UpdateUserInput): Promise<UserView> {
    await this.ensureSeeded();
    await this.getUserInCompanyOrThrow(input.companyId, input.id);
    const data: {
      name?: string;
      email?: string;
      passwordHash?: string;
    } = {};

    if (input.name != null) {
      data.name = normalizeRequired(input.name, 'User name is required.');
    }

    if (input.email != null) {
      const email = normalizeEmail(input.email);
      await this.assertEmailAvailable(email, input.id);
      data.email = email;
    }

    if (input.password != null) {
      data.passwordHash = await bcrypt.hash(input.password, 10);
    }

    const roles =
      input.roles == null ? undefined : normalizeRoles(input.roles);

    const user = await this.prisma.$transaction(async (db) => {
      await db.user.update({
        where: { id: input.id },
        data,
      });

      if (roles != null) {
        await db.companyMembership.deleteMany({
          where: {
            companyId: input.companyId,
            userId: input.id,
          },
        });
        await db.companyMembership.createMany({
          data: roles.map((role) => ({
            companyId: input.companyId,
            userId: input.id,
            role: toPrismaAppRole(role),
          })),
        });
      }

      return db.user.findUnique({
        where: { id: input.id },
        include: {
          memberships: {
            where: { companyId: input.companyId },
            include: { company: true },
            orderBy: { role: 'asc' },
          },
        },
      });
    });

    if (user == null) {
      throw new UsersServiceError('User not found.');
    }
    return toUserView(user as UserWithMemberships);
  }

  private async getUserInCompanyOrThrow(
    companyId: string,
    userId: string,
  ): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: {
        id: userId,
        memberships: { some: { companyId } },
      },
    });
    if (user == null) {
      throw new UsersServiceError('User not found.');
    }
  }

  private async assertEmailAvailable(
    email: string,
    ignoreUserId?: string,
  ): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { email },
    });
    if (user != null && user.id !== ignoreUserId) {
      throw new UsersServiceError('User email already exists.');
    }
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= seedDemoIdentity(this.prisma);
    return this.seedPromise;
  }
}

function toUserView(user: UserWithMemberships): UserView {
  const membership = user.memberships[0];
  if (membership == null) {
    throw new UsersServiceError('User has no company membership.');
  }

  return {
    id: user.id,
    companyId: membership.company.id,
    companyName: membership.company.name,
    name: user.name,
    email: user.email,
    roles: user.memberships.map((candidate) =>
      fromPrismaAppRole(candidate.role),
    ),
    createdAt: user.createdAt.toISOString(),
    updatedAt: user.updatedAt.toISOString(),
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
