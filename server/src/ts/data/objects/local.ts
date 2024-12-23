import * as fs from "node:fs";
import * as Joda from "@js-joda/core";

import type { Config } from "../../server/config.js";
import * as MimeTypes from "../../util/mime-types.js";
import type { Storage } from "./model.js";
import * as Objects from "./objects.js";
import type { Logging } from "../../server/logging.js";
import { Server } from "../../server/model.js";

/**
 * Store objects as local files, which must then be served somehow. This is
 * intended for local development.
 */
export class LocalObjectStorage implements Storage<Config.LocalObjectStorage> {
  readonly config: Config.LocalObjectStorage;

  constructor(config: Config.LocalObjectStorage) {
    this.config = config;
  }

  static async init(
    config: Config.LocalObjectStorage,
  ): Promise<LocalObjectStorage> {
    await fs.promises.access(
      config.path,
      fs.constants.R_OK | fs.constants.W_OK,
    );
    return new this(config);
  }

  #path(name: string): { content: string; meta: string } {
    const content = `${this.config.path}/${name}`;
    return {
      content,
      meta: `${content}.meta`,
    };
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
      const path = this.#path(name);
      await fs.promises.writeFile(path.content, stream);
      await fs.promises.writeFile(
        path.meta,
        JSON.stringify(meta, undefined, 2),
      );
      return name;
    });
    return { name };
  }

  #filter(minimumAge: Joda.Duration): (name: string) => Promise<boolean> {
    const bornBefore = Joda.ZonedDateTime.now().minus(minimumAge);
    return async (name) => {
      const { birthtime } = await fs.promises.stat(name);
      const born = Joda.nativeJs(birthtime);
      return born.isBefore(bornBefore);
    };
  }

  async *list(
    prefix: string,
    minimumAge?: Joda.Duration,
  ): AsyncIterable<readonly Objects.Reference[]> {
    const filter = minimumAge ? this.#filter(minimumAge) : undefined;
    const dir = await fs.promises.opendir(`${prefix}${this.config.path}`);
    let batch = [];
    let size = 0;
    for await (const file of dir) {
      if (
        !file.name.endsWith(".meta") &&
        (!filter || (await filter(file.name)))
      ) {
        batch.push({ name: file.name });
        size += 1;
      }
      if (size >= 20) {
        yield batch;
        batch = [];
        size = 0;
      }
    }
    if (size > 0) {
      yield batch;
    }
  }

  async retrieve({ name }: Objects.Reference): Promise<Objects.Content> {
    const path = this.#path(name);
    const file = fs.createReadStream(path.content);
    const type = MimeTypes.forExtension(name);
    if (type === undefined) {
      throw new Error(`Unknown file extension: “${name}”.`);
    }
    const meta = JSON.parse(
      await fs.promises.readFile(path.meta, { encoding: "utf-8" }),
    );
    return Promise.resolve({ type, data: file, meta });
  }

  async delete({ name }: Objects.Reference): Promise<boolean> {
    try {
      const path = this.#path(name);
      await fs.promises.rm(path.content);
      await fs.promises.rm(path.meta);
      return true;
    } catch (error: unknown) {
      return false;
    }
  }
}
