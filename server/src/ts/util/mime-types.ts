import * as MimeTypes from "mime-types";

import * as Arrays from "./arrays.js";

const shortestExtensions = new Map(
  Object.entries(MimeTypes.extensions).map(([mimeType, extensions]) => [
    mimeType,
    Arrays.shortest(extensions),
  ]),
);
export const shortestExtension = (mimeType: string): string | undefined =>
  shortestExtensions.get(mimeType);

export const forExtension = (extension: string): string | undefined => {
  const mimeType = MimeTypes.lookup(extension);
  return mimeType !== false ? mimeType : undefined;
};

export * as MimeTypes from "./mime-types.js";
