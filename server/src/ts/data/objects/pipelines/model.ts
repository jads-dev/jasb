import type { Config } from "../../../server/config.js";
import type { Objects } from "../model.js";

export interface Stage {
  process(
    config: Config.ObjectStorage,
    data: Objects.Content,
  ): Promise<Objects.Content>;
}

export type Pipeline = readonly Stage[];

export * as Pipelines from "./model.js";
