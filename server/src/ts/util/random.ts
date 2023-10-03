import * as Crypto from "crypto";
import Util from "util";

export const randomBytes = Util.promisify(Crypto.randomBytes);

export const secureRandomString = async (bytes: number): Promise<string> =>
  (await randomBytes(bytes)).toString("base64url");

export * as Random from "./random.js";
