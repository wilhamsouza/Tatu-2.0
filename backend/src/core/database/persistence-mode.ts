export type PersistenceMode = 'memory' | 'prisma';

export function resolvePersistenceMode(): PersistenceMode {
  const configured = (process.env.TATUZIN_PERSISTENCE ?? 'memory')
    .trim()
    .toLowerCase();

  return configured === 'prisma' ? 'prisma' : 'memory';
}
