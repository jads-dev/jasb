import * as Crypto from "crypto";
import Util from "util";

const randomBytes = Util.promisify(Crypto.randomBytes);

export const secureRandomString = async (bytes: number): Promise<string> =>
  (await randomBytes(bytes)).toString("base64");

export * as Random from "./random";
