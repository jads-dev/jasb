import "../scss/index.scss";
import "../../elm-material/src/mts/material.mjs";

import { Elm } from "../elm/JoeBets.mjs";
import * as SessionStore from "./session-store.mjs";
import * as Store from "./store.mjs";

const store = Store.init();
const sessionStore = SessionStore.init();

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const app: Elm.JoeBets.App = Elm.JoeBets.init({
  flags: {
    ...Store.flags(store),
  },
});

Store.ports(store, app.ports);
SessionStore.ports(sessionStore, app.ports);
