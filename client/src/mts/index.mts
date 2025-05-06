import "@fireworks-js/web";
import "../../components/gacha-card/mts/gacha-card.mjs";
import "../../elm-material/src/js/all.js";

import { Elm } from "../elm/Jasb.mjs";
import * as BaseUrl from "./base-url.mjs";
import * as SessionStore from "./session-store.mjs";
import * as Store from "./store.mjs";
import * as WebSocket from "./web-socket.mjs";
import * as Select from "./select.mjs";
import * as Scroll from "./scroll.mjs";

const baseUrl = BaseUrl.discover();

const store = Store.init();
const sessionStore = SessionStore.init();
const webSocketManager = WebSocket.init(baseUrl);

const app = Elm.Jasb.init({
  flags: {
    base: `${baseUrl.protocol}//${baseUrl.host}${baseUrl.path}`,
    ...Store.flags(store),
  },
});

Store.ports(store, app.ports);
SessionStore.ports(sessionStore, app.ports);
WebSocket.ports(webSocketManager, app.ports);
Select.ports(app.ports);
Scroll.ports(app.ports);
