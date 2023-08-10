import { StatusCodes } from "http-status-codes";
import type * as Koa from "koa";
import { SchemaValidationError } from "slonik/dist/errors.js";

import { Auth } from "./auth.js";
import type { Logging } from "./logging.js";

export class WebError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export const handler = (
  log: Logging.Logger,
  error: unknown,
): { status: number; message: string } => {
  if (error instanceof WebError) {
    log.warn(error.message);
    return { status: error.status, message: error.message };
  } else if (error instanceof SchemaValidationError) {
    log.error(error.message, {
      exception: error,
      sql: error.sql,
      row: JSON.stringify(error.row, undefined, 2),
      issues: JSON.stringify(error.issues, undefined, 2),
    });
    return {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      message: "Unhandled database error.",
    };
  } else {
    log.error("Unresolved error: ", { exception: error });
    return {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      message: "Unhandled server eror.",
    };
  }
};

export const middleware =
  (log: Logging.Logger): Koa.Middleware =>
  async (ctx, next): Promise<void> => {
    try {
      await next();
    } catch (error) {
      const { status, message } = handler(log, error);
      if (status === StatusCodes.UNAUTHORIZED) {
        ctx.cookies.set(Auth.sessionCookieName, null, { signed: true });
      }
      ctx.status = status;
      ctx.body = message;
    }
  };

export * as Errors from "./errors.js";
