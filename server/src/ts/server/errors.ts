import { default as StatusCodes } from "http-status-codes";
import type * as Koa from "koa";
import { SchemaValidationError } from "slonik/dist/src/errors.js";

import { Auth } from "./auth.js";
import type { Logging } from "./logging.js";

export class WebError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export const handler = (log: Logging.Logger, error: unknown): number => {
  if (error instanceof WebError) {
    log.warn(error.message);
    return error.status;
  } else if (error instanceof SchemaValidationError) {
    log.error(error.message, {
      exception: error,
      sql: error.sql,
      row: JSON.stringify(error.row, undefined, 2),
      issues: JSON.stringify(error.issues, undefined, 2),
    });
    return StatusCodes.INTERNAL_SERVER_ERROR;
  } else {
    log.error("Unresolved error: ", { exception: error });
    return StatusCodes.INTERNAL_SERVER_ERROR;
  }
};

export const middleware =
  (log: Logging.Logger): Koa.Middleware =>
  async (ctx, next): Promise<void> => {
    try {
      await next();
    } catch (error) {
      const finalError = handler(log, error);
      if (finalError === StatusCodes.UNAUTHORIZED) {
        ctx.cookies.set(Auth.sessionCookieName, null, { signed: true });
      }
      ctx.status = finalError;
    }
  };

export * as Errors from "./errors.js";
