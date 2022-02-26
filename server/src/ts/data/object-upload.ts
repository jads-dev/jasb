import { default as Crypto } from "crypto";

import { Config } from "../server/config.js";

export interface UseCase {
  name: (originalName: string, data: Uint8Array) => string;
  cacheControl?: string;
  allowOverwrite: boolean;
}

export function nameFunction(
  config: Config.ObjectUploadDetails["name"],
): (originalName: string, data: Uint8Array) => string {
  switch (config?.method) {
    case "hash":
      return (originalName, data) => {
        const extensions = originalName.split(".").slice(1).join(".");
        const sha256 = Crypto.createHash(config.algorithm);
        sha256.update(data);
        return `${sha256.digest("base64url")}.${extensions}`;
      };

    case undefined:
      return (originalName) => originalName;
  }
}

export const details = ({
  name,
  cacheMaxAge,
  allowOverwrite,
}: Config.ObjectUploadDetails): UseCase => ({
  name: nameFunction(name),
  ...(cacheMaxAge !== undefined
    ? { cacheControl: `max-age=${cacheMaxAge.seconds()}` }
    : {}),
  allowOverwrite: allowOverwrite === true,
});

export interface ObjectUploader {
  upload: (
    name: string,
    contentType: string,
    stream: Uint8Array,
    metadata?: Record<string, string>,
  ) => Promise<URL>;

  delete: (url: string) => Promise<void>;
}

export async function init(
  config: Config.ObjectUpload | undefined,
): Promise<ObjectUploader | undefined> {
  switch (config?.service) {
    case "oci": {
      const { OciObjectUploader } = await import("./object-upload/oci.js");
      return new OciObjectUploader(config);
    }

    case undefined:
      return undefined;
  }
}

export * as ObjectUpload from "./object-upload.js";
