import { default as Winston } from "winston";

import { Auth } from "./auth";
import { Config } from "./config";
import { Store } from "./store";

export type State = {
  config: Config.Server;
  logger: Winston.Logger;
  store: Store;
  auth: Auth;
};

export * as Server from "./model";
