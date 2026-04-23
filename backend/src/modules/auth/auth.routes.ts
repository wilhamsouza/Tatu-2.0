import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { AuthServiceContract } from './auth.contract.js';
import { AuthServiceError } from './auth.service.js';

const loginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

export function createAuthRouter(
  authService: AuthServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.post('/login', validateRequest(loginSchema), async (request, response) => {
    try {
      const session = await authService.login(
        request.body.email,
        request.body.password,
      );
      response.status(200).json(session);
    } catch (error) {
      response.status(error instanceof AuthServiceError ? 401 : 500).json({
        message: error instanceof Error ? error.message : 'Unexpected error.',
      });
    }
  });

  router.post('/refresh', validateRequest(refreshSchema), async (request, response) => {
    try {
      const session = await authService.refresh(request.body.refreshToken);
      response.status(200).json(session);
    } catch (error) {
      response.status(error instanceof AuthServiceError ? 401 : 500).json({
        message: error instanceof Error ? error.message : 'Unexpected error.',
      });
    }
  });

  router.post('/logout', validateRequest(refreshSchema), async (request, response) => {
    await authService.logout(request.body.refreshToken);
    response.status(204).send();
  });

  router.get(
    '/me',
    authenticate(jwtService),
    (request: AuthenticatedRequest, response) => {
      response.status(200).json({
        user: request.auth,
      });
    },
  );

  return router;
}
