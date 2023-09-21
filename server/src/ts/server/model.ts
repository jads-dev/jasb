import type { ObjectUploader } from "../data/object-upload.js";
import type { Store } from "../data/store.js";
import type { Auth } from "./auth.js";
import type { Config } from "./config.js";
import type { Notifier } from "./external-notifier.js";
import type { Logging } from "./logging.js";
import type { WebSockets } from "./web-sockets.js";

export interface State {
  config: Config.Server;
  logger: Logging.Logger;
  store: Store;
  auth: Auth;
  webSockets: WebSockets;
  externalNotifier: Notifier;
  imageUpload: ObjectUploader | undefined;
  avatarCache: ObjectUploader | undefined;
}

export * as Server from "./model.js";
