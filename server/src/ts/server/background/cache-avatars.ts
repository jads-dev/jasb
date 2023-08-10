import { OciError } from "oci-sdk";

import type { ObjectUploader } from "../../data/object-upload.js";
import type { AvatarCache } from "../../internal.js";
import { Iterables } from "../../util/iterables.js";
import { Promises } from "../../util/promises.js";
import { Urls } from "../../util/urls.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";

export const cacheAvatars = (server: Server.State) => {
  const config = server.config.avatarCache;
  const avatarCache = server.avatarCache;
  if (config !== undefined && avatarCache !== undefined) {
    return async (server: Server.State, logger: Logging.Logger) => {
      await Promises.wait(config.backgroundTaskFrequency);

      const added = await addToCacheBatch(
        server,
        logger,
        avatarCache,
        config.cacheBatchSize,
      );
      if (added > 0) {
        logger.info(`Cached ${added} new avatars.`);
      } else {
        logger.debug("No avatars to cache.");
      }

      const deleted = await removeFromCacheBatch(
        server,
        logger,
        avatarCache,
        config.garbageCollectBatchSize,
      );
      logger.level();
      if (deleted > 0) {
        logger.info(`Deleted ${deleted} unused avatars.`);
      } else {
        logger.debug("No unused avatars to delete.");
      }

      return false;
    };
  } else {
    return undefined;
  }
};

async function addToCacheBatch(
  server: Server.State,
  logger: Logging.Logger,
  avatarCache: ObjectUploader,
  batchSize: number,
): Promise<number> {
  const needsToBeCached = await server.store.avatarsToCache(batchSize);
  const added = [
    ...Iterables.filterUndefined(
      await Promise.all(
        needsToBeCached.map((meta) => cache(logger, avatarCache, meta)),
      ),
    ),
  ];
  await server.store.updateCachedAvatars(added);
  return added.length;
}

async function removeFromCacheBatch(
  server: Server.State,
  logger: Logging.Logger,
  avatarCache: ObjectUploader,
  batchSize: number,
): Promise<number> {
  const noLongerNeeded =
    await server.store.avatarCacheGarbageCollection(batchSize);
  const deleted = [
    ...Iterables.filterUndefined(
      await Promise.all(
        noLongerNeeded.map((url) => deleteCached(logger, avatarCache, url)),
      ),
    ),
  ];
  await server.store.deleteCachedAvatars(deleted);
  return deleted.length;
}

async function deleteCached(
  logger: Logging.Logger,
  avatarCache: ObjectUploader,
  url: string,
): Promise<string | undefined> {
  try {
    await avatarCache.delete(url);
    return url;
  } catch (error) {
    if (error instanceof OciError) {
      if (error.serviceCode === "NotFound") {
        return url;
      }
    }
    logger.warn(
      `Error trying to delete cached avatar: ${(error as Error)?.message}.`,
      {
        exception: error,
        error,
      },
    );
    return undefined;
  }
}

async function cache(
  logger: Logging.Logger,
  avatarCache: ObjectUploader,
  meta: AvatarCache.Meta & AvatarCache.Url,
): Promise<{ oldUrl: string; newUrl: string } | undefined> {
  try {
    const response = await fetch(meta.url);
    const contentType = response.headers.get("Content-Type") ?? "";
    if (response.ok) {
      const url = await avatarCache.upload(
        Urls.extractFilename(meta.url),
        contentType,
        new Uint8Array(await response.arrayBuffer()),
        {
          source_url: meta.url,
          source_service: "discord",
          ...(meta.default_index === null
            ? {
                discord_user: meta.discord_user,
                discord_avatar: meta.hash,
              }
            : { discord_default_avatar: `${meta.default_index}` }),
        },
      );
      return { oldUrl: meta.url, newUrl: url.toString() };
    } else {
      logger.warn(
        `Error trying to cache avatar: could not load avatar from source.`,
      );
      return undefined;
    }
  } catch (error) {
    logger.warn(`Error trying to cache avatar: ${(error as Error)?.message}.`, {
      exception: error,
      error,
    });
    return undefined;
  }
}
