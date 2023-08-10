import { default as Router } from "@koa/router";
import * as Schema from "io-ts";

import { Balances } from "../../public/gacha/balances.js";
import { Rarities } from "../../public/gacha/rarities.js";
import type { Server } from "../model.js";
import { requireSession } from "./auth.js";
import { bannersApi } from "./gacha/banners.js";
import { cardsApi } from "./gacha/cards.js";

export const gachaApi = (server: Server.State): Router => {
  const router = new Router();

  const cards = cardsApi(server);
  router.use("/cards", cards.routes(), cards.allowedMethods());

  const banners = bannersApi(server);
  router.use("/banners", banners.routes(), banners.allowedMethods());

  // Get the user's balance.
  router.get("/balance", async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const balance = await server.store.gachaGetBalance(
      sessionCookie.user,
      sessionCookie.session,
    );
    ctx.body = Balances.Balance.encode(Balances.fromInternal(balance));
  });

  // Get the user's balance.
  router.get("/rarities", async (ctx) => {
    const rarities = await server.store.gachaGetRarities();
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Rarities.Slug, Rarities.Rarity]),
    ).encode(rarities.map(Rarities.fromInternal));
  });

  return router;
};
