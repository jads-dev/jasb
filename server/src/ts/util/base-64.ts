import { base64ToUint8Array, uint8ArrayToBase64 } from "uint8array-extras";

export const encode = (value: Uint8Array, options: { urlSafe: boolean }) =>
  uint8ArrayToBase64(value, options);

export const decode = (encoded: string) => base64ToUint8Array(encoded);

export * as Base64 from "./base-64.js";
