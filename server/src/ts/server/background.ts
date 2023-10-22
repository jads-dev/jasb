import { cacheObjects } from "./background/cache-objects.js";
import { garbageCollectObjects } from "./background/garbage-collect-objects.js";
import { garbageCollectSessions } from "./background/garbage-collect-sessions.js";
import { refreshDiscordTokens } from "./background/refresh-discord-sessions.js";
import type { Tasks } from "./background/tasks.js";
import type { Logging } from "./logging.js";
import type { Server } from "./model.js";

export const runTask = (
  server: Server.State,
  logger: Logging.Logger,
  task: Tasks.Task<Tasks.SingleRunResult>,
): void => {
  task.execute(server, logger, { iteration: 0 }).catch((error: unknown) => {
    logger.error(
      { err: error },
      `Unhandled exception in background task “${task.name}”.`,
    );
  });
};

const runTaskRepeatedly = async (
  server: Server.State,
  parentLogger: Logging.Logger,
  task: Tasks.Task,
): Promise<void> => {
  const logger = parentLogger.child({
    task: task.name,
    ...task.details,
  });
  try {
    logger.info("Repeated background task started.");
    let iteration = 0;
    let finished = false;
    while (!finished) {
      const iterationLogger = logger.child({
        taskIteration: iteration,
      });
      const result = await task.execute(server, iterationLogger, { iteration });
      finished = result.finished;
      iteration += 1;
    }
    logger.info("Repeated background task finished.");
  } catch (error: unknown) {
    logger.error(
      { err: error },
      `Unhandled exception in background task “${task.name}”.`,
    );
  }
};

const tasks = (server: Server.State): (Tasks.Task | undefined)[] => [
  garbageCollectSessions(server),
  refreshDiscordTokens(server),
  cacheObjects(server),
  garbageCollectObjects(server),
];
export const runTasks = async (server: Server.State): Promise<void> => {
  const logger = server.logger.child({
    system: "background-task",
  });
  await Promise.all(
    tasks(server).map((task) =>
      task !== undefined ? runTaskRepeatedly(server, logger, task) : undefined,
    ),
  );
};

export * as Background from "./background.js";
