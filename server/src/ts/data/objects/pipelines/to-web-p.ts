import { default as Sharp } from "sharp";

import type { Config } from "../../../server/config.js";
import type { Objects } from "../model.js";
import { Pipelines } from "./model.js";

export interface Settings {
  targetSize?: [number, number];
}

export class Stage implements Pipelines.Stage {
  settings: Settings;

  constructor(settings: Settings) {
    this.settings = settings;
  }

  process(
    config: Config.ObjectStorage,
    content: Objects.Content,
  ): Promise<Objects.Content> {
    if (content.type !== "image/svg+xml") {
      const pipeline = Sharp();
      content.data.pipe(pipeline as unknown as NodeJS.WritableStream);
      if (this.settings.targetSize !== undefined) {
        const [width, height] = this.settings.targetSize;
        pipeline.resize(width, height, { withoutEnlargement: true });
      }
      pipeline.webp({
        effort: config.webp?.effort ?? 4,
      });
      return Promise.resolve({
        data: pipeline,
        type: "image/webp",
        meta: content.meta,
      });
    } else {
      return Promise.resolve(content);
    }
  }
}

export * as ToWebP from "./to-web-p.js";
