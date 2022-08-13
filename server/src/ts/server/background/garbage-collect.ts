import { Promises } from "../../util/promises.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";

export async function garbageCollect(
  server: Server.State,
  logger: Logging.Logger,
) {
  await Promises.wait(server.config.store.garbageCollectionFrequency);
  const garbageCollected = await server.store.garbageCollect();

  logger.info(`Garbage collected ${garbageCollected.length} expired sessions.`);
}
