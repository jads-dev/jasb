import { AxiosResponse, default as Axios } from "axios";
import { StatusCodes } from "http-status-codes";
import { OciError } from "oci-sdk";
import { default as Winston } from "winston";

import { ObjectUploader } from "../../data/object-upload";
import { AvatarCache } from "../../internal";
import { Key } from "../../internal/avatar-cache";
import { Iterables } from "../../util/iterables";
import { Promises } from "../../util/promises";
import { Server } from "../model";

export const cacheAvatars = (server: Server.State) => {
  const config = server.config.avatarCache;
  const avatarCache = server.avatarCache;
  if (config !== undefined && avatarCache !== undefined) {
    return async (server: Server.State) => {
      await Promises.wait(config.backgroundTaskFrequency);

      const added = await addToCacheBatch(
        server,
        avatarCache,
        config.cacheBatchSize,
      );
      server.logger.info(`Cached ${added} new avatars.`);

      const deleted = await removeFromCacheBatch(
        server,
        avatarCache,
        config.garbageCollectBatchSize,
      );
      server.logger.info(`Deleted ${deleted} unused avatars.`);
    };
  } else {
    return undefined;
  }
};

async function addToCacheBatch(
  server: Server.State,
  avatarCache: ObjectUploader,
  batchSize: number,
): Promise<number> {
  const needsToBeCached = await server.store.avatarsToCache(batchSize);
  const added = [
    ...Iterables.filterUndefined(
      await Promise.all(
        needsToBeCached.map((details) =>
          cache(server.logger, avatarCache, details),
        ),
      ),
    ),
  ];
  await server.store.updateCachedAvatars(added);
  return added.length;
}

async function removeFromCacheBatch(
  server: Server.State,
  avatarCache: ObjectUploader,
  batchSize: number,
): Promise<number> {
  const noLongerNeeded = await server.store.avatarCacheGarbageCollection(
    batchSize,
  );
  const deleted = [
    ...Iterables.filterUndefined(
      await Promise.all(
        noLongerNeeded.map((url) =>
          deleteCached(server.logger, avatarCache, url),
        ),
      ),
    ),
  ];
  await server.store.deleteCachedAvatars(deleted);
  return deleted.length;
}

function expandDetails({
  id,
  discriminator,
  avatar,
}: AvatarCache.CacheDetails): {
  key: Key;
  path: string;
  filename: string;
} {
  if (avatar === null) {
    const defaultAvatar = (parseInt(discriminator) % 5).toString();
    return {
      key: { discriminator: defaultAvatar },
      path: "embed/avatars",
      filename: `${defaultAvatar}.png`,
    };
  } else {
    return {
      key: { user: id, avatar: avatar },
      path: `avatars/${id}`,
      filename: `${avatar}.webp`,
    };
  }
}

async function deleteCached(
  logger: Winston.Logger,
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

async function fetch(
  url: string,
): Promise<AxiosResponse<ArrayBuffer> | undefined> {
  try {
    return await Axios.get<ArrayBuffer>(url, {
      responseType: "arraybuffer",
    });
  } catch (error) {
    if (
      Axios.isAxiosError(error) &&
      error.response?.status === StatusCodes.NOT_FOUND
    ) {
      return undefined;
    } else {
      throw error;
    }
  }
}

async function cache(
  logger: Winston.Logger,
  avatarCache: ObjectUploader,
  details: AvatarCache.CacheDetails,
): Promise<{ user: string; key: AvatarCache.Key; url: string } | undefined> {
  const { key, path, filename } = expandDetails(details);
  const discordUrl = `https://cdn.discordapp.com/${path}/${filename}`;
  try {
    const response = await fetch(discordUrl);
    if (response !== undefined) {
      const url = await avatarCache.upload(
        filename,
        response.headers["content-type"],
        new Uint8Array(response.data),
        key,
      );
      return { user: details.id, key: key, url: url.toString() };
    } else {
      if (details.avatar !== null) {
        return cache(logger, avatarCache, { ...details, avatar: null });
      } else {
        logger.warn(
          `Error trying to cache avatar: could not load fallback avatar.`,
        );
        return undefined;
      }
    }
  } catch (error) {
    logger.warn(`Error trying to cache avatar: ${(error as Error)?.message}.`, {
      exception: error,
      error,
    });
    return undefined;
  }
}
