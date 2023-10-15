import { cacheAvatars } from "./background/cache-avatars.js";
import { garbageCollect } from "./background/garbage-collect.js";
import type { Tasks } from "./background/tasks.js";
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
  task: Tasks.Task | undefined,
): Promise<void> => {
  if (task !== undefined) {
    const logger = parentLogger.child({
      task: taskName,
    });
    await runTaskRepeatedly(server, logger, task).catch((error: unknown) => {
      logger.error(
        { err: error },
        `Unhandled exception in background task ${taskName}.`,
      );
    });
  }
};

const runTaskRepeatedly = async (
  server: Server.State,
  parentLogger: Logging.Logger,
  task: Tasks.Task,
): Promise<void> => {
  let iteration = 0;
  let finished = false;
  while (!finished) {
    const logger = parentLogger.child({
      taskIteration: iteration,
    });
    const result = await task(server, logger, { iteration });
    finished = result.finished;
    iteration += 1;
  }
};

export * as Background from "./background.js";
