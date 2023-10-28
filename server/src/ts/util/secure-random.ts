import { Base64 } from "./base-64.js";

export const bytes = (length: number): Uint8Array =>
  crypto.getRandomValues(new Uint8Array(length));

export const string = (lengthInBytes: number): string =>
  Base64.encode(bytes(lengthInBytes), { urlSafe: true });

export * as SecureRandom from "./secure-random.js";
