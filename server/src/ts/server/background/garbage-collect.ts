import { Promises } from "../../util/promises.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";

export async function garbageCollect(
  server: Server.State,
  logger: Logging.Logger,
) {
  await Promises.wait(server.config.store.garbageCollectionFrequency);
  const garbageCollected = await server.store.garbageCollect();

  if (garbageCollected.length > 0) {
    logger.info(
      `Garbage collected ${garbageCollected.length} expired sessions.`,
    );
  } else {
    logger.debug("Garbage collection found no expired sessions.");
  }

  return false;
}
