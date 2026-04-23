import { AppRole as PrismaAppRole, type PrismaClient } from '@prisma/client';

import type { AppRole } from '../../core/auth/request-context.js';
import { demoUsers } from './demo-users.js';

export async function seedDemoIdentity(prisma: PrismaClient): Promise<void> {
  const [firstUser] = demoUsers;
  await prisma.company.upsert({
    where: { id: firstUser.companyId },
    create: {
      id: firstUser.companyId,
      name: firstUser.companyName,
    },
    update: {
      name: firstUser.companyName,
    },
  });

  for (const user of demoUsers) {
    await prisma.user.upsert({
      where: { id: user.userId },
      create: {
        id: user.userId,
        name: user.name,
        email: user.email,
        passwordHash: user.passwordHash,
      },
      update: {
        name: user.name,
        email: user.email,
        passwordHash: user.passwordHash,
      },
    });

    for (const role of user.roles) {
      await prisma.companyMembership.upsert({
        where: {
          companyId_userId_role: {
            companyId: user.companyId,
            userId: user.userId,
            role: toPrismaAppRole(role),
          },
        },
        create: {
          companyId: user.companyId,
          userId: user.userId,
          role: toPrismaAppRole(role),
        },
        update: {},
      });
    }
  }
}

export function toPrismaAppRole(role: AppRole): PrismaAppRole {
  switch (role) {
    case 'manager':
      return PrismaAppRole.MANAGER;
    case 'seller':
      return PrismaAppRole.SELLER;
    case 'cashier':
      return PrismaAppRole.CASHIER;
    case 'crm_user':
      return PrismaAppRole.CRM_USER;
    default:
      return PrismaAppRole.ADMIN;
  }
}

export function fromPrismaAppRole(role: PrismaAppRole): AppRole {
  switch (role) {
    case PrismaAppRole.MANAGER:
      return 'manager';
    case PrismaAppRole.SELLER:
      return 'seller';
    case PrismaAppRole.CASHIER:
      return 'cashier';
    case PrismaAppRole.CRM_USER:
      return 'crm_user';
    default:
      return 'admin';
  }
}
