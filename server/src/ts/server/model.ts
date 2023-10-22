import { default as KoaRouter } from "@koa/router";
import type { default as Koa } from "koa";

import type { Objects } from "../data/objects/model.js";
import type { Store } from "../data/store.js";
import type { Auth } from "./auth.js";
import type { Config } from "./config.js";
import type { Notifier } from "./external-notifier.js";
import type { Logging } from "./logging.js";
import type { WebSockets } from "./web-sockets.js";

export interface State {
  readonly config: Config.Server;
  readonly logger: Logging.Logger;
  readonly store: Store;
  readonly auth: Auth;
  readonly webSockets: WebSockets;
  readonly externalNotifier: Notifier;
  readonly objectStorage: Objects.Storage | undefined;
}

export interface Context extends Koa.Context {
  logger: Logging.Logger;
}

export type Router = KoaRouter<Koa.DefaultState, Context>;
export const router = () => new KoaRouter<Koa.DefaultState, Context>();

export * as Server from "./model.js";
