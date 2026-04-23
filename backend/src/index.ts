import { createApp } from './app.js';
import { disconnectPrismaClient } from './core/database/prisma.client.js';
import { logger } from './core/logging/logger.js';
import { validateRuntimeEnvironment } from './core/validation/runtime-env.js';

const port = Number(process.env.PORT ?? 3333);
validateRuntimeEnvironment();
const app = createApp();
const server = app.listen(port, () => {
  logger.info({ port }, 'Tatuzin backend listening');
});

let shuttingDown = false;

async function shutdown(signal: NodeJS.Signals): Promise<void> {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;

  logger.info({ signal }, 'Shutting down Tatuzin backend');

  const forceExitTimer = setTimeout(() => {
    logger.error('Force exit after shutdown timeout');
    process.exit(1);
  }, 10000);
  forceExitTimer.unref();

  server.close(async (error) => {
    if (error != null) {
      logger.error({ error }, 'Error while closing HTTP server');
      process.exitCode = 1;
    }

    try {
      await disconnectPrismaClient();
    } catch (disconnectError) {
      logger.error(
        { disconnectError },
        'Error while disconnecting Prisma client',
      );
      process.exitCode = 1;
    }

    process.exit();
  });
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    void shutdown(signal);
  });
}
