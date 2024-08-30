import { StatusCodes } from "http-status-codes";
import { SchemaValidationError } from "slonik";

import type { Logging } from "./logging.js";

export class WebError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export const handler = (
  logger: Logging.Logger,
  error: unknown,
): { status: number; message: string } => {
  if (error instanceof WebError) {
    logger.warn(error.message);
    return { status: error.status, message: error.message };
  } else if (error instanceof SchemaValidationError) {
    const { sql, row, issues, message } = error;
    logger.error(
      {
        err: error,
        sql: sql,
        row: JSON.stringify(row, undefined, 2),
        issues: JSON.stringify(issues, undefined, 2),
      },
      message,
    );
    return {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      message: "Unhandled database error.",
    };
  } else {
    logger.error({ err: error }, "Unresolved error.");
    return {
      status: StatusCodes.INTERNAL_SERVER_ERROR,
      message: "Unhandled server error.",
    };
  }
};

export * as Errors from "./errors.js";
