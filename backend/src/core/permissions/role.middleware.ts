import type { NextFunction, Response } from 'express';

import type {
  AppRole,
  AuthenticatedRequest,
} from '../auth/request-context.js';

export function requireRoles(...allowedRoles: AppRole[]) {
  return (
    request: AuthenticatedRequest,
    response: Response,
    next: NextFunction,
  ): void => {
    const currentRoles = request.auth?.roles ?? [];
    const isAuthorized = currentRoles.some((role) => allowedRoles.includes(role));

    if (!isAuthorized) {
      response.status(403).json({
        message: 'Forbidden for the current role.',
        requiredRoles: allowedRoles,
      });
      return;
    }

    next();
  };
}
