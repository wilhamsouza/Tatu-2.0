import { Router } from 'express';
import { z } from 'zod';

import { authenticate } from '../../core/auth/auth.middleware.js';
import { JwtService } from '../../core/auth/jwt.service.js';
import type { AuthenticatedRequest } from '../../core/auth/request-context.js';
import { requireRoles } from '../../core/permissions/role.middleware.js';
import { requireTenancy } from '../../core/tenancy/tenancy.middleware.js';
import { validateRequest } from '../../core/validation/validate-request.js';
import type { DeviceServiceContract } from './device.contract.js';

const registerDeviceSchema = z.object({
  body: z.object({
    deviceId: z.string().min(1),
    platform: z.string().min(1),
    appVersion: z.string().optional(),
  }),
  params: z.object({}).optional().default({}),
  query: z.object({}).optional().default({}),
});

export function createDevicesRouter(
  deviceService: DeviceServiceContract,
  jwtService: JwtService,
): Router {
  const router = Router();

  router.post(
    '/register',
    authenticate(jwtService),
    requireTenancy,
    requireRoles('admin', 'manager', 'seller', 'cashier', 'crm_user'),
    validateRequest(registerDeviceSchema),
    async (request: AuthenticatedRequest, response) => {
      const auth = request.auth!;
      const device = await deviceService.register({
        companyId: auth.companyId,
        userId: auth.userId,
        deviceId: request.body.deviceId,
        platform: request.body.platform,
        appVersion: request.body.appVersion,
      });

      response.status(201).json(device);
    },
  );

  return router;
}
