import type { NextFunction, Request, Response } from 'express';
import type { ZodTypeAny } from 'zod';

export function validateRequest(schema: ZodTypeAny) {
  return (request: Request, response: Response, next: NextFunction): void => {
    const result = schema.safeParse({
      body: request.body,
      params: request.params,
      query: request.query,
    });

    if (!result.success) {
      response.status(400).json({
        message: 'Validation error.',
        issues: result.error.flatten(),
      });
      return;
    }

    request.body = result.data.body;
    next();
  };
}
