import { Promises } from "../../util/promises.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";
import type { Tasks } from "./tasks.js";

export const garbageCollectSessions = (server: Server.State): Tasks.Task => {
  const frequency = server.config.auth.sessions.garbageCollectionFrequency;
  return {
    name: "Garbage Collect Sessions",
    details: {
      frequency,
    },
    execute: async (
      server: Server.State,
      logger: Logging.Logger,
    ): Promise<Tasks.Result> => {
      await Promises.wait(frequency);
      const garbageCollected = await server.store.garbageCollectSessions();

      if (garbageCollected.length > 0) {
        logger.info(
          `Garbage collected ${garbageCollected.length} expired sessions.`,
        );
      } else {
        logger.debug("Garbage collection found no expired sessions.");
      }

      return { finished: false };
    },
  };
};
