import * as Joda from "@js-joda/core";

export const wait = async (duration: Joda.Duration): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, duration.toMillis()));

export * as Promise from "./promise";
