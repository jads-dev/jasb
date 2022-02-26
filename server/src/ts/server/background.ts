import { Server } from "./model.js";
import { cacheAvatars } from "./background/cache-avatars.js";
import { garbageCollect } from "./background/garbage-collect.js";

export async function runTasks(server: Server.State) {
  runTaskRepeatedlyInBackground(server, "Garbage Collection", garbageCollect);
  runTaskRepeatedlyInBackground(
    server,
    "Avatar Cacheing",
    cacheAvatars(server),
  );
}

const runTaskRepeatedlyInBackground = (
  server: Server.State,
  taskName: string,
  task: ((server: Server.State) => Promise<void>) | undefined,
) => {
  if (task !== undefined) {
    runTaskRepeatedly(server, task).catch((error) =>
      server.logger.error(
        `Unhandled exception in background task ${taskName}: ${
          (error as Error)?.message
        }.`,
        {
          exception: error,
        },
      ),
    );
  }
};

const runTaskRepeatedly = async (
  server: Server.State,
  task: (server: Server.State) => Promise<void>,
): Promise<void> => {
  // eslint-disable-next-line no-constant-condition
  while (true) {
    await task(server);
  }
};

export * as Background from "./background.js";
