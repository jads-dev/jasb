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
  switch (config.service) {
    case "oci": {
      logger.info("Configured with OCI object storage.");
      const { OciObjectStorage } = await import("./objects/oci.js");
      return new OciObjectStorage(config);
    }

    default:
      return Expect.exhaustive("object storage service")(config.service);
  }
};

export const upload = async (
  server: Server.State,
  logger: Logging.Logger,
  { type: objectType, pipeline }: ProcessedType,
  content: Objects.Content,
  metadata: Record<string, string>,
): Promise<Objects.Reference> => {
  const { objectStorage } = server;
  if (objectStorage !== null) {
    return await objectStorage.upload(
      server,
      logger,
      objectType.prefix,
      await pipeline.process(objectStorage.config, content),
      metadata,
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
        stream: FS.createReadStream(file.filepath),
        mimeType: file.mimetype,
      };
      const object = await objectStorage.upload(
        ctx.server,
        ctx.logger,
        objectType.prefix,
        await pipeline.process(objectStorage.config, content),
        {
          uploader: Credentials.actingUser(credential),
        },
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
