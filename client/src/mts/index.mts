import "../scss/index.scss";
import "../../elm-material/src/mts/material.mjs";
import "@fireworks-js/web";

import { Elm } from "../elm/JoeBets.mjs";
import * as BaseUrl from "./base-url.mjs";
import * as CopyImage from "./copy-image.mjs";
import * as SessionStore from "./session-store.mjs";
import * as Store from "./store.mjs";
import * as WebSocket from "./web-socket.mjs";

const baseUrl = BaseUrl.discover();

const store = Store.init();
const sessionStore = SessionStore.init();
const webSocketManager = WebSocket.init(baseUrl);

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const app: Elm.JoeBets.App = Elm.JoeBets.init({
  flags: {
    base: `${baseUrl.protocol}//${baseUrl.host}${baseUrl.path}`,
    ...Store.flags(store),
  },
});

Store.ports(store, app.ports);
SessionStore.ports(sessionStore, app.ports);
WebSocket.ports(webSocketManager, app.ports);
CopyImage.ports(app.ports);
