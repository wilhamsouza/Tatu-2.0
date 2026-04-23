import { isPrismaConfigured } from '../database/prisma.client.js';
import { resolvePersistenceMode } from '../database/persistence-mode.js';

const defaultJwtSecrets = new Set<string>([
  'tatuzin-access-secret',
  'tatuzin-refresh-secret',
]);

export function validateRuntimeEnvironment(): void {
  const persistenceMode = resolvePersistenceMode();

  if (persistenceMode === 'prisma' && !isPrismaConfigured()) {
    throw new Error(
      'TATUZIN_PERSISTENCE=prisma exige DATABASE_URL configurada.',
    );
  }

  if (process.env.NODE_ENV !== 'production') {
    return;
  }

  validateProductionSecret('JWT_ACCESS_SECRET');
  validateProductionSecret('JWT_REFRESH_SECRET');
}

export function resolveAllowedCorsOrigins(): string[] {
  return (process.env.CORS_ORIGIN ?? '')
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

export function isOriginAllowed(
  origin: string | undefined,
  allowedOrigins: string[],
): boolean {
  if (origin == null || origin.trim().length === 0) {
    return true;
  }

  if (allowedOrigins.includes('*')) {
    return true;
  }

  if (allowedOrigins.length === 0) {
    return process.env.NODE_ENV !== 'production';
  }

  return allowedOrigins.includes(origin);
}

function validateProductionSecret(name: string): void {
  const value = (process.env[name] ?? '').trim();
  if (value.length < 32) {
    throw new Error(
      `${name} precisa ter pelo menos 32 caracteres em producao.`,
    );
  }

  if (defaultJwtSecrets.has(value)) {
    throw new Error(`${name} nao pode usar o valor padrao em producao.`);
  }
}
