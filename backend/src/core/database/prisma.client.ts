import { PrismaClient } from '@prisma/client';

let prismaClient: PrismaClient | undefined;

export function getPrismaClient(): PrismaClient {
  prismaClient ??= new PrismaClient({
    log:
      process.env.NODE_ENV === 'production'
        ? ['error']
        : ['warn', 'error'],
  });
  return prismaClient;
}

export async function disconnectPrismaClient(): Promise<void> {
  if (prismaClient == null) {
    return;
  }

  await prismaClient.$disconnect();
  prismaClient = undefined;
}

export function isPrismaConfigured(): boolean {
  return (process.env.DATABASE_URL ?? '').trim().length > 0;
}
