import type Stream from "node:stream";

import type * as Joda from "@js-joda/core";

import type { Config } from "../../server/config.js";
import type { Logging } from "../../server/logging.js";
import type { Server } from "../../server/model.js";
import type { Objects } from "./objects.ts";

export interface Storage<
  Config extends Config.ObjectStorage = Config.ObjectStorage,
> {
  readonly config: Config;

  // Store an object in storage under the given prefix, returning a
  // reference to it.
  store(
    server: Server.State,
    logger: Logging.Logger,
    prefix: string,
    { data, type, meta }: Objects.Content,
  ): Promise<Objects.Reference>;
  // Get all objects with the given prefix from storage.
  list(
    prefix: string,
    minimumAge?: Joda.Duration,
  ): AsyncIterable<readonly Objects.Reference[]>;
  // Get a URL to an object from its reference.
  url(reference: Objects.Reference): string;
  // Turn a URL to an object into its reference.
  reference(url: string): Objects.Reference | undefined;
  // Delete an object from storage, returning if an object was found and deleted.
  delete(object: Objects.Reference): Promise<boolean>;
}

export type { Reference, Content } from "./objects.js";
export * as Objects from "./model.js";
