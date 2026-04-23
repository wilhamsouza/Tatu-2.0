import type { NextFunction, Response } from 'express';

import type { AuthenticatedRequest } from '../auth/request-context.js';

export function requireTenancy(
  request: AuthenticatedRequest,
  response: Response,
  next: NextFunction,
): void {
  if (!request.auth?.companyId) {
    response.status(400).json({ message: 'Company context is required.' });
    return;
  }

  next();
}
