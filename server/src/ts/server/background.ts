import { cacheAvatars } from "./background/cache-avatars.js";
import { garbageCollect } from "./background/garbage-collect.js";
import type { Logging } from "./logging.js";
import type { Server } from "./model.js";

export const runTasks = async (server: Server.State): Promise<void> => {
  const logger = server.logger.child({
    system: "background-task",
  });
  await Promise.all([
    runTaskRepeatedlyInBackground(
      server,
      logger,
      "Garbage Collection",
      garbageCollect,
    ),
    runTaskRepeatedlyInBackground(
      server,
      logger,
      "Avatar Caching",
      cacheAvatars(server),
    ),
  ]);
};

const runTaskRepeatedlyInBackground = async (
  server: Server.State,
  parentLogger: Logging.Logger,
  taskName: string,
  task:
    | ((server: Server.State, logger: Logging.Logger) => Promise<boolean>)
    | undefined,
): Promise<void> => {
  if (task !== undefined) {
    const logger = parentLogger.child({
      task: taskName,
    });
    await runTaskRepeatedly(server, logger, task).catch((error) => {
      logger.error(
        `Unhandled exception in background task ${taskName}: ${
          (error as Error).message
        }.`,
        {
          exception: error as Error,
        },
      );
    });
  }
};

const runTaskRepeatedly = async (
  server: Server.State,
  logger: Logging.Logger,
  task: (server: Server.State, logger: Logging.Logger) => Promise<boolean>,
): Promise<void> => {
  let finished = false;
  while (!finished) {
    finished = await task(server, logger);
  }
};

export * as Background from "./background.js";
