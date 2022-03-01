import * as Bunyan from "bunyan";
import type * as Koa from "koa";
import { default as KoaBunyan } from "koa-bunyan-logger";

import { Config } from "./config.js";

export type Logger = Bunyan;

export const init = (config: Config.Logging): Logger =>
  Bunyan.createLogger({
    name: "JASB",
    level: config.level,
  });

export const middleware = (logger: Logger): Koa.Middleware => KoaBunyan(logger);

export * as Logging from "./logging.js";
