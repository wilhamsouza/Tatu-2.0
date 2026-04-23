import { randomUUID } from 'node:crypto';

import jwt, { type JwtPayload } from 'jsonwebtoken';

import type { AppRole, AuthContext } from './request-context.js';

interface TokenPayload extends JwtPayload {
  sub: string;
  email: string;
  name: string;
  companyId: string;
  companyName: string;
  roles: AppRole[];
  tokenType: 'access' | 'refresh';
}

export class JwtService {
  constructor(
    private readonly accessSecret: string,
    private readonly refreshSecret: string,
  ) {}

  signAccessToken(context: AuthContext): string {
    return jwt.sign(
      {
        sub: context.userId,
        email: context.email,
        name: context.name,
        companyId: context.companyId,
        companyName: context.companyName,
        roles: context.roles,
        tokenType: 'access',
        jti: randomUUID(),
      } satisfies TokenPayload,
      this.accessSecret,
      { expiresIn: '8h' },
    );
  }

  signRefreshToken(context: AuthContext): string {
    return jwt.sign(
      {
        sub: context.userId,
        email: context.email,
        name: context.name,
        companyId: context.companyId,
        companyName: context.companyName,
        roles: context.roles,
        tokenType: 'refresh',
        jti: randomUUID(),
      } satisfies TokenPayload,
      this.refreshSecret,
      { expiresIn: '30d' },
    );
  }

  verifyAccessToken(token: string): AuthContext {
    const payload = jwt.verify(token, this.accessSecret) as TokenPayload;
    if (payload.tokenType !== 'access') {
      throw new Error('Invalid access token type.');
    }
    return this.toContext(payload);
  }

  verifyRefreshToken(token: string): AuthContext {
    const payload = jwt.verify(token, this.refreshSecret) as TokenPayload;
    if (payload.tokenType !== 'refresh') {
      throw new Error('Invalid refresh token type.');
    }
    return this.toContext(payload);
  }

  private toContext(payload: TokenPayload): AuthContext {
    return {
      userId: payload.sub,
      email: payload.email,
      name: payload.name,
      companyId: payload.companyId,
      companyName: payload.companyName,
      roles: payload.roles,
    };
  }
}
