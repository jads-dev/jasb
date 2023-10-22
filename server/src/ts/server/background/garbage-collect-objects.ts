import * as Joda from "@js-joda/core";
import * as Slonik from "slonik";

import { Objects } from "../../data/objects.js";
import { Promises } from "../../util/promises.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";
import type { Tasks } from "./tasks.js";

export const garbageCollectObjects = (
  server: Server.State,
): Tasks.Task | undefined => {
  const { objectStorage } = server;
  const types = Objects.allTypes;
  if (objectStorage !== undefined) {
    const config = objectStorage.config.garbageCollection;
    return {
      name: "Garbage Collect Object Storage",
      details: {
        ...config,
        prefixes: types.map(({ prefix }) => prefix),
      },
      execute: async (
        server: Server.State,
        logger: Logging.Logger,
        _meta: { iteration: number },
      ): Promise<Tasks.Result> => {
        await Promises.wait(config.frequency);
        const start = performance.now();
        let referencesCollected = 0;
        let objectsCollected = 0;
        for (const { name, prefix, table, objectColumn } of types) {
          const tableIdentifier = Slonik.sql.identifier([table]);
          const columnIdentifier = Slonik.sql.identifier([table, objectColumn]);
          referencesCollected +=
            await server.store.objectsDeleteUnusedReferences(
              name,
              tableIdentifier,
              columnIdentifier,
            );
          for await (const batch of objectStorage.list(
            prefix,
            config.minimumAge,
          )) {
            const unused = await server.store.objectsWithoutReferences(
              name,
              batch,
            );
            for (const reference of unused) {
              await objectStorage.delete(reference);
              objectsCollected += 1;
            }
          }
        }
        const details = {
          duration: Joda.Duration.ofMillis(performance.now() - start),
          objectReferencesGarbageCollected: referencesCollected,
          objectsGarbageCollected: objectsCollected,
        };
        if (referencesCollected > 0 || objectsCollected > 0) {
          logger.info(
            details,
            `Garbage collected ${referencesCollected} unused references and ${objectsCollected} unused objects.`,
          );
        } else {
          logger.debug(details, `No unused references or objects to delete.`);
        }
        return { finished: false };
      },
    };
  } else {
    return undefined;
  }
};
