import { default as Winston } from "winston";

import { ObjectUploader } from "../data/object-upload";
import { Store } from "../data/store";
import { Auth } from "./auth";
import { Config } from "./config";
import { Notifier } from "./notifier";

export type State = {
  config: Config.Server;
  logger: Winston.Logger;
  store: Store;
  auth: Auth;
  notifier: Notifier;
  imageUpload: ObjectUploader | undefined;
  avatarCache: ObjectUploader | undefined;
};

export * as Server from "./model";
