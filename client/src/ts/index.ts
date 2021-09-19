import "../scss/index.scss";
import "elm-material/src/ts/material";
import "./img-fallback";

import { Elm } from "../elm/JoeBets";
import * as Store from "./store";

const store = Store.init();

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const app: Elm.JoeBets.App = Elm.JoeBets.init({
  flags: {
    ...Store.flags(store),
  },
});

Store.ports(store, app.ports);
