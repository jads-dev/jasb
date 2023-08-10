export const extractFilename = (url: string) => {
  const pathname = new URL(url).pathname;
  return pathname.substring(pathname.lastIndexOf("/") + 1);
};

export * as Urls from "./urls.js";
