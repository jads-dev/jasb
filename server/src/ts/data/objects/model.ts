import type Stream from "node:stream";

import type * as Joda from "@js-joda/core";

import type { Config } from "../../server/config.js";
import type { Logging } from "../../server/logging.js";
import type { Server } from "../../server/model.js";

export interface Content {
  stream: Stream.Readable;
  mimeType: string;
}

export interface Reference {
  name: string;
}

export interface Storage {
  config: Config.ObjectStorage;
  // Upload an object to storage under the given prefix, getting back a
  // reference to it.
  upload(
    server: Server.State,
    logger: Logging.Logger,
    prefix: string,
    content: Content,
    metadata: Record<string, string>,
  ): Promise<Reference>;
  // Get all images with the given prefix from storage.
  list(
    prefix: string,
    minimumAge?: Joda.Duration,
  ): AsyncIterable<readonly Reference[]>;
  // Get a URL to an object from its reference.
  url(reference: Reference): string;
  // Turn a URL to an object into its reference.
  reference(url: string): Reference | undefined;
  // Delete an object from storage.
  delete(object: Reference): Promise<void>;
}

export * as Objects from "./model.js";
