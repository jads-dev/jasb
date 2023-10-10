import { default as Router } from "@koa/router";

import { Balances } from "../../public/gacha/balances.js";
import { Context } from "../../public/gacha/context.js";
import { Qualities } from "../../public/gacha/qualities.js";
import { Rarities } from "../../public/gacha/rarities.js";
import type { Server } from "../model.js";
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
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    const balance = await server.store.gachaGetBalance(credential);
    ctx.body = Balances.Balance.encode(Balances.fromInternal(balance));
  });

  // Get the context for cards.
  router.get("/context", async (ctx) => {
    const [rarities, qualities] = await Promise.all([
      server.store.gachaGetRarities(),
      server.store.gachaGetQualities(),
    ]);
    ctx.body = Context.encode({
      rarities: rarities.map(Rarities.fromInternal),
      qualities: qualities.map(Qualities.fromInternal),
    });
  });

  return router;
};
