import { default as FS } from "node:fs";

import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Credentials } from "../server/auth/credentials.js";
import type { Config } from "../server/config.js";
import { WebError } from "../server/errors.js";
import type { Logging } from "../server/logging.js";
import { Server } from "../server/model.js";
import { Arrays } from "../util/arrays.js";
import { Expect } from "../util/expect.js";
import type { Objects } from "./objects/model.js";
import type { ProcessedType } from "./objects/types.js";

export const storage = async (
  logger: Logging.Logger,
  config: Config.ObjectStorage | undefined,
): Promise<Objects.Storage | null> => {
  if (config === undefined) {
    logger.warn("Configured with no object storage.");
    return null;
  }

  const service = config.service;
  switch (service) {
    case "s3": {
      logger.info("Configured with S3 API object storage.");
      const { S3ObjectStorage } = await import("./objects/s3.js");
      return new S3ObjectStorage(config);
    }

    case "local": {
      logger.info("Configured with local file object storage.");
      const { LocalObjectStorage } = await import("./objects/local.js");
      return new LocalObjectStorage(config);
    }

    default:
      return Expect.exhaustive("object storage service")(service);
  }
};

export const upload = async (
  server: Server.State,
  logger: Logging.Logger,
  { type: objectType, pipeline }: ProcessedType,
  content: Objects.Content,
): Promise<Objects.Reference> => {
  const { objectStorage } = server;
  if (objectStorage !== null) {
    return await objectStorage.store(
      server,
      logger,
      objectType.prefix,
      await pipeline.process(objectStorage.config, content),
    );
  } else {
    throw new WebError(
      StatusCodes.SERVICE_UNAVAILABLE,
      "Object storage not available.",
    );
  }
};

export const uploadHandler =
  ({
    type: objectType,
    pipeline,
  }: ProcessedType): ((ctx: Server.Context) => Promise<void>) =>
  async (ctx) => {
    const { auth, store, objectStorage } = ctx.server;
    if (objectStorage !== null) {
      const credential = await auth.requireIdentifyingCredential(ctx);
      await store.validateUpload(credential);
      const [file, ...additional] = Arrays.singletonOrArray(
        ctx.request.files?.["file"],
      );
      if (additional.length > 0 || file === undefined) {
        throw new WebError(
          StatusCodes.BAD_REQUEST,
          "Must include a single file.",
        );
      }
      if (file.mimetype === null) {
        throw new WebError(StatusCodes.BAD_REQUEST, "File type not provided.");
      }
      const content = {
        data: FS.createReadStream(file.filepath),
        type: file.mimetype,
        meta: Credentials.objectMeta(credential),
      };
      const object = await objectStorage.store(
        ctx.server,
        ctx.logger,
        objectType.prefix,
        await pipeline.process(objectStorage.config, content),
      );
      ctx.body = Schema.strict({ url: Schema.string }).encode({
        url: objectStorage.url(object),
      });
    } else {
      throw new WebError(
        StatusCodes.SERVICE_UNAVAILABLE,
        "No object storage available.",
      );
    }
  };

export * from "./objects/model.js";
export * from "./objects/types.js";
export * as Objects from "./objects.js";
