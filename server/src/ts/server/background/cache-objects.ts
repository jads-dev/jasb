import { Readable } from "node:stream";
import { ReadableStream } from "node:stream/web";

import * as Joda from "@js-joda/core";
import * as Slonik from "slonik";

import { Objects } from "../../data/objects.js";
import { Promises } from "../../util/promises.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";
import type { Tasks } from "./tasks.js";

function* filterResults<Value>(
  logger: Logging.Logger,
  results: Iterable<PromiseSettledResult<Value>>,
): Iterable<Value> {
  for (const result of results) {
    if (result.status === "fulfilled") {
      yield result.value;
    } else {
      logger.error(
        { err: result.reason as unknown },
        `Problem retrieving value to cache.`,
      );
    }
  }
}

const fetchContent = async (url: string): Promise<Objects.Content> => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(
      `Bad status (${response.status}) trying to cache object: ${url}`,
    );
  }
  const stream = response.body;
  const mimeType = response.headers.get("content-type");
  if (mimeType === null) {
    throw new Error(`No content type from object to cache: ${url}`);
  }
  if (stream === null) {
    throw new Error(`No body from object to cache: ${url}`);
  }
  return {
    type: mimeType,
    data: Readable.fromWeb(stream as ReadableStream),
    meta: { source: url.length > 255 ? `${url.slice(0, 254)}…` : url },
  };
};

export const cacheObjects = (server: Server.State): Tasks.Task | undefined => {
  const { objectStorage } = server;
  const types = Objects.allTypes;
  return objectStorage !== null
    ? {
        name: "Cache To Object Storage",
        details: {
          ...objectStorage.config.cache,
          prefixes: types.map(({ prefix }) => prefix),
        },
        execute: async (
          server: Server.State,
          logger: Logging.Logger,
          _meta: { iteration: number },
        ): Promise<Tasks.Result> => {
          await Promises.wait(objectStorage.config.cache.frequency);
          const start = performance.now();
          let cacheAttempts = 0;
          let cachedAmount = 0;
          for (const { name, prefix, table, objectColumn } of types) {
            const uncached = await server.store.objectReferenceFindUncached(
              objectStorage.config.cache.batchSize - cacheAttempts,
              name,
              Slonik.sql.identifier([table]),
              Slonik.sql.identifier([table, objectColumn]),
            );
            const cached = await Promise.allSettled(
              uncached.map(async ({ id, url }) => {
                try {
                  const existingReference = objectStorage.reference(url);
                  if (existingReference !== undefined) {
                    return {
                      id,
                      oldUrl: url,
                      name: existingReference.name,
                      url,
                    };
                  } else {
                    const content = await fetchContent(url);
                    const reference = await objectStorage.store(
                      server,
                      logger,
                      prefix,
                      content,
                    );
                    return {
                      id,
                      oldUrl: url,
                      name: reference.name,
                      url: objectStorage.url(reference),
                    };
                  }
                } catch (error: unknown) {
                  await server.store.objectReferenceIncrementFailure(name, id);
                  throw error;
                }
              }),
            );
            cachedAmount += await server.store.objectReferenceUpdateCached(
              name,
              filterResults(logger, cached),
            );
            cacheAttempts += uncached.length;
            if (cacheAttempts >= objectStorage.config.cache.batchSize) {
              break;
            }
          }
          const details = {
            duration: Joda.Duration.ofMillis(performance.now() - start),
            objectsCacheAttempts: cacheAttempts,
            objectsCached: cachedAmount,
          };
          if (cacheAttempts > 0) {
            logger.info(
              details,
              `Attempted to cache ${cacheAttempts} objects (${cachedAmount} successful).`,
            );
          } else {
            logger.debug(details, `No objects require caching.`);
          }
          return { finished: false };
        },
      }
    : undefined;
};
