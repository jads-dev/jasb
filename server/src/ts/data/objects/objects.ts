import { default as Crypto } from "node:crypto";
import { default as FS } from "node:fs";
import { default as OS } from "node:os";
import type * as Stream from "node:stream";
import { pipeline } from "node:stream/promises";

import { MimeTypes } from "../../util/mime-types.js";
import { SecureRandom } from "../../util/secure-random.js";
import { uint8ArrayToBase64 } from "uint8array-extras";

export interface Reference {
  name: string;
}

export interface Content {
  type: string;
  data: Stream.Readable;
  meta: Record<string, string>;
}

export const withHash = async <Result>(
  stream: Stream.Readable,
  f: (stream: Stream.Readable, hash: Uint8Array) => Promise<Result>,
): Promise<Result> => {
  const tempFilename = `${OS.tmpdir()}/${uint8ArrayToBase64(
    SecureRandom.bytes(64),
    { urlSafe: true },
  )}`;
  const sha256 = Crypto.createHash("sha256");
  stream.pipe(sha256);
  await pipeline(stream, FS.createWriteStream(tempFilename));
  try {
    return await f(FS.createReadStream(tempFilename), sha256.digest());
  } finally {
    await FS.promises.rm(tempFilename);
  }
};

export const nameFromHash = (
  prefix: string,
  sha256Hash: Uint8Array,
  type: string,
): string => {
  const extension = MimeTypes.shortestExtension(type);
  if (extension === undefined) {
    throw new Error(`Unknown mime type: “${type}”.`);
  }
  return `${prefix}${uint8ArrayToBase64(new Uint8Array(sha256Hash), {
    urlSafe: true,
  })}.${extension}`;
};

export * as Objects from "./objects.js";
