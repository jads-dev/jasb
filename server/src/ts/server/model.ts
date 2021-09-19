import { default as Winston } from "winston";

import { Store } from "../data/store";
import { Auth } from "./auth";
import { Config } from "./config";
import { Notifier } from "./notifier";
import { ObjectUploader } from "../data/object-upload";

export type State = {
  config: Config.Server;
  logger: Winston.Logger;
  store: Store;
  auth: Auth;
  notifier: Notifier;
  objectUploader: ObjectUploader;
};

export * as Server from "./model";
