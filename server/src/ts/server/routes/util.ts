import { StatusCodes } from "http-status-codes";
import { type Middleware } from "koa";
import { koaBody } from "koa-body";
import type { KoaBodyMiddlewareOptions } from "koa-body/lib/types.js";

import { WebError } from "../errors.js";

const bodyParams: Partial<KoaBodyMiddlewareOptions> = {
  patchKoa: true,
  jsonLimit: "1mb",
  encoding: "utf-8",
  multipart: false,
  urlencoded: false,
  text: false,
  json: true,
  jsonStrict: true,
  includeUnparsed: false,
  onError: (error: Error): never => {
    throw new WebError(StatusCodes.BAD_REQUEST, error.message);
  },
};

export const body: Middleware = koaBody(bodyParams);

export const uploadBody: Middleware = koaBody({
  ...bodyParams,
  multipart: true,
  formidable: { maxFileSize: 25 * 1024 * 1024 },
  json: false,
});
