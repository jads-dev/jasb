import { default as Crypto } from "node:crypto";
import { default as FS } from "node:fs";
import { default as OS } from "node:os";
import { default as Stream } from "node:stream";
import { default as StreamP } from "node:stream/promises";

import * as Joda from "@js-joda/core";
import * as MimeTypes from "mime-types";
import { default as OciCommon } from "oci-common";
import { DefaultRetryCondition } from "oci-common/lib/retrier.js";
import { default as Oci } from "oci-objectstorage";
import { OciError } from "oci-sdk";

import { Background } from "../../server/background.js";
import type { Config } from "../../server/config.js";
import type { Logging } from "../../server/logging.js";
import { Server } from "../../server/model.js";
import { Arrays } from "../../util/arrays.js";
import { SecureRandom } from "../../util/secure-random.js";
import { SizeCounter } from "../../util/streams.js";
import { Objects } from "./model.js";

// Stop OCI spamming the console quite as much, thanks.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const errorFilter = (error: any) =>
  !(
    error.code || // eslint-disable-line @typescript-eslint/no-unsafe-member-access
    // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access
    (error.errorObject &&
      // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access,@typescript-eslint/no-unsafe-argument
      DefaultRetryCondition.shouldBeRetried(error.errorObject))
  );

export class OciObjectStorage implements Objects.Storage {
  readonly config: Config.OciObjectStorage;
  readonly #client;
  readonly #baseUrl;

  constructor(config: Config.OciObjectStorage) {
    this.config = config;
    this.#client = new Oci.ObjectStorageClient(
      {
        authenticationDetailsProvider:
          new OciCommon.SimpleAuthenticationDetailsProvider(
            config.tenancy,
            config.user,
            config.fingerprint,
            config.privateKey.value,
            config.passphrase?.value ?? null,
            OciCommon.Region.fromRegionId(config.region),
          ),
      },
      {
        circuitBreaker: new OciCommon.CircuitBreaker({
          errorFilter,
        }),
        retryConfiguration: {
          terminationStrategy: new OciCommon.MaxAttemptsTerminationStrategy(1),
        },
      },
    );
    this.#baseUrl = `/assets/objects/`;
  }

  url({ name }: Objects.Reference): string {
    return `${this.#baseUrl}${name}`;
  }

  reference(url: string): Objects.Reference | undefined {
    return url.startsWith(this.#baseUrl)
      ? { name: url.slice(this.#baseUrl.length) }
      : undefined;
  }

  #hash(stream: Stream.Readable, algorithm: string): Crypto.Hash {
    const hash = Crypto.createHash(algorithm);
    stream.pipe(hash as unknown as NodeJS.WritableStream);
    return hash;
  }

  async *list(
    prefix: string,
    minimumAge?: Joda.Duration,
  ): AsyncIterable<readonly Objects.Reference[]> {
    const filterByAge: <Value extends { timeCreated?: Date | undefined }>(
      objects: readonly Value[],
    ) => readonly Value[] =
      minimumAge !== undefined
        ? (objects) =>
            objects.filter(({ timeCreated }) =>
              timeCreated !== undefined
                ? Joda.Duration.between(
                    Joda.Instant.ofEpochMilli(timeCreated.getTime()),
                    Joda.Instant.now(),
                  ).compareTo(minimumAge) > 0
                : true,
            )
        : (objects) => objects;
    for await (const batch of this.#client.listObjectsResponseIterator({
      namespaceName: this.config.namespace,
      bucketName: this.config.bucket,
      prefix,
    })) {
      yield filterByAge(batch.listObjects.objects).map(({ name }) => ({
        name,
      }));
    }
  }

  async upload(
    server: Server.State,
    logger: Logging.Logger,
    prefix: string,
    { stream, mimeType }: Objects.Content,
    metadata: Record<string, string>,
  ): Promise<Objects.Reference> {
    const extension = Arrays.shortest(MimeTypes.extensions[mimeType] ?? []);
    if (extension === undefined) {
      throw new Error(`No extension known for mime type “${mimeType}”.`);
    }
    const tempFilename = `${OS.tmpdir()}/${SecureRandom.string(64)}`;
    const md5 = this.#hash(stream, "md5");
    const sha256 = this.#hash(stream, "sha256");
    const sizeCounter = new SizeCounter();
    stream.pipe(sizeCounter as unknown as NodeJS.WritableStream);
    await StreamP.pipeline(stream , FS.createWriteStream(tempFilename) as unknown as NodeJS.WritableStream);
    try {
      const reference = {
        name: `${prefix}${sha256.digest("base64url")}.${extension}`,
      };
      try {
        await this.#client.putObject({
          putObjectBody: FS.createReadStream(tempFilename),
          contentLength: sizeCounter.size,
          namespaceName: this.config.namespace,
          bucketName: this.config.bucket,
          objectName: reference.name,
          contentMD5: md5.digest("base64"),
          contentType: mimeType,
          ifNoneMatch: "*",
          opcMeta: metadata,
        });
      } catch (error) {
        if (
          error instanceof OciError &&
          error.serviceCode === "IfNoneMatchFailed"
        ) {
          return reference;
        } else {
          throw error;
        }
      }
      return reference;
    } finally {
      Background.runTask(server, logger, {
        name: "Delete Object Upload Temporary File",
        details: { filename: tempFilename },
        execute: async () => {
          await FS.promises.rm(tempFilename);
          return { finished: true };
        },
      });
    }
  }

  async delete(reference: Objects.Reference): Promise<void> {
    await this.#client.deleteObject({
      namespaceName: this.config.namespace,
      bucketName: this.config.bucket,
      objectName: reference.name,
    });
  }
}
