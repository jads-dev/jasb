import { StatusCodes } from "http-status-codes";
import { SchemaValidationError } from "slonik/dist/errors.js";

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
    log.error(
      {
        err: error,
        sql: error.sql,
        row: JSON.stringify(error.row, undefined, 2),
        issues: JSON.stringify(error.issues, undefined, 2),
      },
      error.message,
    );
    return {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      message: "Unhandled database error.",
    };
  } else {
    log.error({ err: error }, "Unresolved error.");
    return {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      message: "Unhandled server error.",
    };
  }
};

export * as Errors from "./errors.js";
