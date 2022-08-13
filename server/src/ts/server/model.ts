import type { ObjectUploader } from "../data/object-upload.js";
import type { Store } from "../data/store.js";
import type { Auth } from "./auth.js";
import type { Config } from "./config.js";
import type { Logging } from "./logging.js";
import type { Notifier } from "./notifier.js";

export type State = {
  config: Config.Server;
  logger: Logging.Logger;
  store: Store;
  auth: Auth;
  notifier: Notifier;
  imageUpload: ObjectUploader | undefined;
  avatarCache: ObjectUploader | undefined;
};

export * as Server from "./model.js";
