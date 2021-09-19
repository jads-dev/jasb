import { default as Express } from "express";
import { default as StatusCodes } from "http-status-codes";
import { default as Winston } from "winston";

import { Auth } from "./auth";

export class WebError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export const handler = (log: Winston.Logger, error: Error): number => {
  if (error instanceof WebError) {
    log.warn(error.message);
    return error.status;
  }
  log.error("Unresolved error: ", { exception: error });
  return StatusCodes.INTERNAL_SERVER_ERROR;
};

export const express: (
  log: Winston.Logger
) => (
  error: Error,
  req: Express.Request,
  res: Express.Response,
  next: Express.NextFunction
) => void = (log) => (error, req, res, next) => {
  if (res.headersSent) {
    next(error);
  } else {
    const finalError = handler(log, error);
    if (finalError === StatusCodes.UNAUTHORIZED) {
      res.clearCookie(Auth.sessionCookieName);
    }
    res.status(finalError).send();
  }
};

export * as Errors from "./errors";
