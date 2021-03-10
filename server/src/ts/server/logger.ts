import type { Handler } from "express";
import { default as ExpressWinston } from "express-winston";
import { default as Winston } from "winston";

const lines = /^(?!\s*$)/gm;
const indent = (string: string) => string.replace(lines, " ".repeat(2));

const logFormat = Winston.format.printf((info) => {
  const exception = info.exception ? indent("\n" + info.exception.stack) : "";

  const metadata = indent(
    "\n" +
      JSON.stringify(
        {
          ...info,
          exception: undefined,
          level: undefined,
          message: undefined,
          splat: undefined,
        },
        null,
        2
      )
  );

  return `${info.level}: ${info.message}${exception}${metadata}`;
});

export const create = (logLevel: string): Winston.Logger =>
  Winston.createLogger({
    level: logLevel,
    transports: [new Winston.transports.Console()],
    format: Winston.format.combine(
      Winston.format.timestamp(),
      Winston.format.colorize(),
      logFormat
    ),
  });

export const express = (logger: Winston.Logger): Handler =>
  ExpressWinston.logger({
    winstonInstance: logger,
    requestWhitelist: [
      "url",
      "headers",
      "method",
      "httpVersion",
      "originalUrl",
      "query",
      "body",
    ],
    responseWhitelist: ["statusCode", "body"],
    ignoredRoutes: ["/private-api/status", "/private-api/status/live"],
  });

export * as Logger from "./logger";
