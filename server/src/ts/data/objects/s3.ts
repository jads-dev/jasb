import { Readable } from "node:stream";
import type { ReadableStream } from "node:stream/web";
import * as Joda from "@js-joda/core";

import {
  DeleteObjectCommand,
  GetObjectCommand,
  GetObjectTaggingCommand,
  paginateListObjectsV2,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { uint8ArrayToBase64 } from "uint8array-extras";

import type { Config } from "../../server/config.js";
import { Objects } from "./objects.js";
import type { Storage } from "./model.js";
import type { Logging } from "../../server/logging.js";
import { Server } from "../../server/model.js";

/**
 * Store objects on any S3-compatible object storage service (which is most of
 * them).
 */
export class S3ObjectStorage implements Storage<Config.S3ObjectStorage> {
  readonly config: Config.S3ObjectStorage;
  readonly #client: S3Client;

  constructor(config: Config.S3ObjectStorage) {
    this.config = config;
    this.#client = new S3Client({
      endpoint: config.endpoint,
      credentials: {
        accessKeyId: config.accessKey.id,
        secretAccessKey: config.accessKey.secret.value,
      },
      region: "auto",
    });
  }

  static init(config: Config.S3ObjectStorage): Promise<S3ObjectStorage> {
    return Promise.resolve(new this(config));
  }

  url({ name }: Objects.Reference): string {
    return `${this.config.public}${name}`;
  }

  reference(url: string): Objects.Reference | undefined {
    return url.startsWith(this.config.public)
      ? { name: url.slice(this.config.public.length) }
      : undefined;
  }

  async store(
    _server: Server.State,
    _logger: Logging.Logger,
    prefix: string,
    { data, type, meta }: Objects.Content,
  ): Promise<Objects.Reference> {
    const name = await Objects.withHash(data, async (stream, hash) => {
      const name = Objects.nameFromHash(prefix, hash, type);
      const command = new PutObjectCommand({
        Bucket: this.config.bucket,
        Key: name,
        Body: stream,
        ChecksumSHA256: uint8ArrayToBase64(hash),
        ...(this.config.tagging
          ? {
              Tagging: Object.entries(meta)
                .map((key, value) => `${key}=${value}`)
                .join("&"),
            }
          : {}),
      });
      await this.#client.send(command);
      return name;
    });
    return { name };
  }

  #filter(minimumAge: Joda.Duration): (created: Date) => Promise<boolean> {
    const createdBefore = Joda.ZonedDateTime.now().minus(minimumAge);
    return async (created) => Joda.nativeJs(created).isBefore(createdBefore);
  }

  async *list(
    prefix: string,
    minimumAge?: Joda.Duration,
  ): AsyncIterable<readonly Objects.Reference[]> {
    const filter = minimumAge ? this.#filter(minimumAge) : undefined;
    for await (const page of paginateListObjectsV2(
      { client: this.#client },
      {
        Bucket: this.config.bucket,
        Prefix: prefix,
      },
    )) {
      const batch = [];
      if (page.Contents) {
        for (const object of page.Contents) {
          if (
            object.Key &&
            (!filter ||
              (object.LastModified && (await filter(object.LastModified))))
          )
            batch.push({ name: object.Key });
        }
      }
      return batch;
    }
  }

  async #retrieveMeta(name: string): Promise<Record<string, string>> {
    if (this.config.tagging) {
      const command = new GetObjectTaggingCommand({
        Bucket: this.config.bucket,
        Key: name,
      });
      const response = await this.#client.send(command);
      return Object.fromEntries(
        (response.TagSet ?? []).map(({ Key, Value }) => [Key, Value]),
      );
    } else {
      return {};
    }
  }

  async retrieve({ name }: Objects.Reference): Promise<Objects.Content> {
    const command = new GetObjectCommand({
      Bucket: this.config.bucket,
      Key: name,
    });
    const response = await this.#client.send(command);
    if (response.Body === undefined) {
      throw new Error("No body in retrieve response.");
    }
    if (response.ContentType === undefined) {
      throw new Error("No content type in retrieve response.");
    }
    const meta = (response.TagCount ?? 0 > 0) ? this.#retrieveMeta(name) : {};
    return {
      type: response.ContentType,
      data: Readable.fromWeb(
        response.Body.transformToWebStream() as ReadableStream,
      ),
      meta,
    };
  }

  async delete({ name }: Objects.Reference): Promise<boolean> {
    const command = new DeleteObjectCommand({
      Bucket: this.config.bucket,
      Key: name,
    });
    await this.#client.send(command);
    return true;
  }
}
