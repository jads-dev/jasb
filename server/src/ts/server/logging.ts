import type * as Koa from "koa";
import * as Pino from "pino";
import * as PinoHttp from "pino-http";

import type { Config } from "./config.js";
import type { Server } from "./model.js";

export type Logger = Pino.Logger;

export const init = (config: Config.Logging): Logger =>
  Pino.pino({
    name: "JASB",
    level: config.level,
  });

export const middleware = (
  logger: Logger,
): Koa.Middleware<Koa.DefaultState, Server.Context> => {
  const http = PinoHttp.pinoHttp({ logger });
  return async (ctx, next) => {
    http(ctx.req, ctx.res);
    ctx.logger = ctx.req.log;
    await next();
  };
};

export * as Logging from "./logging.js";
