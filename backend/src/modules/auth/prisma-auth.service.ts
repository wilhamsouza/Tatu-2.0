import { createHash } from 'node:crypto';

import { AppRole as PrismaAppRole, type PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthContext } from '../../core/auth/request-context.js';
import type { AuthServiceContract } from './auth.contract.js';
import {
  fromPrismaAppRole,
  seedDemoIdentity,
} from './prisma-identity.seed.js';
import {
  AuthServiceError,
  type AuthSession,
} from './auth.service.js';

type UserWithMemberships = {
  id: string;
  email: string;
  name: string;
  memberships: Array<{
    role: PrismaAppRole;
    company: {
      id: string;
      name: string;
    };
  }>;
};

const accessTokenExpiresInMs = 8 * 60 * 60 * 1000;
const refreshTokenExpiresInMs = 30 * 24 * 60 * 60 * 1000;

export class PrismaAuthService implements AuthServiceContract {
  private seedPromise?: Promise<void>;

  constructor(
    private readonly prisma: PrismaClient,
    private readonly jwtService: JwtService,
  ) {}

  async login(email: string, password: string): Promise<AuthSession> {
    await this.ensureSeeded();

    const user = await this.prisma.user.findUnique({
      where: { email: email.trim().toLowerCase() },
      include: {
        memberships: {
          include: { company: true },
          orderBy: { role: 'asc' },
        },
      },
    });
    if (user == null) {
      throw new AuthServiceError('Invalid credentials.');
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw new AuthServiceError('Invalid credentials.');
    }

    return this.issueSession(user);
  }

  async refresh(refreshToken: string): Promise<AuthSession> {
    await this.ensureSeeded();

    const tokenContext = this.jwtService.verifyRefreshToken(refreshToken);
    const refreshTokenHash = hashRefreshToken(refreshToken);
    const refreshSession = await this.prisma.refreshSession.findUnique({
      where: { refreshTokenHash },
      include: {
        user: {
          include: {
            memberships: {
              include: { company: true },
              orderBy: { role: 'asc' },
            },
          },
        },
      },
    });

    if (
      refreshSession == null ||
      refreshSession.userId !== tokenContext.userId ||
      refreshSession.expiresAt <= new Date()
    ) {
      throw new AuthServiceError('Refresh session not found.');
    }

    await this.prisma.refreshSession.delete({
      where: { id: refreshSession.id },
    });

    return this.issueSession(refreshSession.user);
  }

  async logout(refreshToken: string): Promise<void> {
    await this.prisma.refreshSession.deleteMany({
      where: { refreshTokenHash: hashRefreshToken(refreshToken) },
    });
  }

  private async issueSession(user: UserWithMemberships): Promise<AuthSession> {
    const context = toAuthContext(user);
    const expiresAt = new Date(Date.now() + accessTokenExpiresInMs).toISOString();
    const refreshToken = this.jwtService.signRefreshToken(context);

    await this.prisma.refreshSession.create({
      data: {
        userId: context.userId,
        refreshTokenHash: hashRefreshToken(refreshToken),
        expiresAt: new Date(Date.now() + refreshTokenExpiresInMs),
      },
    });

    return {
      user: context,
      tokens: {
        accessToken: this.jwtService.signAccessToken(context),
        refreshToken,
        expiresAt,
      },
    };
  }

  private ensureSeeded(): Promise<void> {
    this.seedPromise ??= seedDemoIdentity(this.prisma);
    return this.seedPromise;
  }
}

function toAuthContext(user: UserWithMemberships): AuthContext {
  const membership = user.memberships[0];
  if (membership == null) {
    throw new AuthServiceError('User has no company membership.');
  }

  const companyId = membership.company.id;
  return {
    userId: user.id,
    email: user.email,
    name: user.name,
    companyId,
    companyName: membership.company.name,
    roles: user.memberships
      .filter((candidate) => candidate.company.id === companyId)
      .map((candidate) => fromPrismaAppRole(candidate.role)),
  };
}

function hashRefreshToken(refreshToken: string): string {
  return createHash('sha256').update(refreshToken).digest('hex');
}
