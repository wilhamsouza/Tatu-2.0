import bcrypt from 'bcryptjs';

import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthContext } from '../../core/auth/request-context.js';
import { demoUsers, type DemoUser } from './demo-users.js';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}

export interface AuthSession {
  user: AuthContext;
  tokens: AuthTokens;
}

export class AuthService {
  constructor(private readonly jwtService: JwtService) {}

  private readonly refreshSessions = new Map<string, string>();

  async login(email: string, password: string): Promise<AuthSession> {
    const user = this.findUserByEmail(email);
    if (!user) {
      throw new AuthServiceError('Invalid credentials.');
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      throw new AuthServiceError('Invalid credentials.');
    }

    return this.issueSession(user);
  }

  refresh(refreshToken: string): AuthSession {
    const user = this.jwtService.verifyRefreshToken(refreshToken);
    const storedUserId = this.refreshSessions.get(refreshToken);
    if (storedUserId !== user.userId) {
      throw new AuthServiceError('Refresh session not found.');
    }

    const demoUser = this.findUserByEmail(user.email);
    if (!demoUser) {
      throw new AuthServiceError('User no longer exists.');
    }

    this.refreshSessions.delete(refreshToken);
    return this.issueSession(demoUser);
  }

  logout(refreshToken: string): void {
    this.refreshSessions.delete(refreshToken);
  }

  private findUserByEmail(email: string): DemoUser | undefined {
    return demoUsers.find(
      (candidate) => candidate.email === email.trim().toLowerCase(),
    );
  }

  private issueSession(user: DemoUser): AuthSession {
    const context: AuthContext = {
      userId: user.userId,
      email: user.email,
      name: user.name,
      companyId: user.companyId,
      companyName: user.companyName,
      roles: user.roles,
    };

    const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString();
    const tokens = {
      accessToken: this.jwtService.signAccessToken(context),
      refreshToken: this.jwtService.signRefreshToken(context),
      expiresAt,
    };

    this.refreshSessions.set(tokens.refreshToken, context.userId);

    return {
      user: context,
      tokens,
    };
  }
}

export class AuthServiceError extends Error {}
