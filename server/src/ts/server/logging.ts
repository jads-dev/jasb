import type * as Koa from "koa";
import { default as KoaPino } from "koa-pino-logger";
import * as Pino from "pino";

import type { Config } from "./config.js";

export type Logger = Pino.Logger;

export const init = (config: Config.Logging): Logger =>
  Pino.pino({
    name: "JASB",
    level: config.level,
  });

export const middleware = (logger: Logger): Koa.Middleware => KoaPino(logger);

export * as Logging from "./logging.js";
