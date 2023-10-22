import type { Config } from "../../server/config.js";
import type { Content } from "./model.js";
import type { Stage } from "./pipelines/model.js";
import { ToWebP } from "./pipelines/to-web-p.js";

export class Pipeline {
  readonly #stages: Stage[] = [];

  static input(): Pipeline {
    return new Pipeline();
  }

  toWebP(settings: ToWebP.Settings): this {
    this.#stages.push(new ToWebP.Stage(settings));
    return this;
  }

  async process(
    config: Config.ObjectStorage,
    content: Content,
  ): Promise<Content> {
    let result = content;
    for (const stage of this.#stages) {
      result = await stage.process(config, result);
    }
    return result;
  }
}

export * from "./pipelines/model.js";
export * as Pipelines from "./pipelines.js";
