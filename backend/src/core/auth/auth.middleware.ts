import type { NextFunction, Response } from 'express';

import type { AuthenticatedRequest } from './request-context.js';
import { JwtService } from './jwt.service.js';

export function authenticate(jwtService: JwtService) {
  return (
    request: AuthenticatedRequest,
    response: Response,
    next: NextFunction,
  ): void => {
    const authorization = request.headers.authorization;
    if (!authorization?.startsWith('Bearer ')) {
      response.status(401).json({ message: 'Missing bearer token.' });
      return;
    }

    try {
      const token = authorization.replace('Bearer ', '').trim();
      request.auth = jwtService.verifyAccessToken(token);
      next();
    } catch (error) {
      response.status(401).json({
        message: 'Invalid access token.',
        details: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  };
}
