import { ObjectUploader } from "../data/object-upload.js";
import { Store } from "../data/store.js";
import { Auth } from "./auth.js";
import { Config } from "./config.js";
import { Logging } from "./logging.js";
import { Notifier } from "./notifier.js";

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
