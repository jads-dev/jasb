import { Promises } from "../../util/promises.js";
import { Server } from "../model.js";

export async function garbageCollect(server: Server.State) {
  await Promises.wait(server.config.store.garbageCollectionFrequency);
  const garbageCollected = await server.store.garbageCollect();

  server.logger.info(
    `Garbage collected ${garbageCollected.length} expired sessions.`,
  );
}
