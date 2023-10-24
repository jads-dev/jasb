import { Balances } from "../../public/gacha/balances.js";
import { Context } from "../../public/gacha/context.js";
import { Qualities } from "../../public/gacha/qualities.js";
import { Rarities } from "../../public/gacha/rarities.js";
import { Server } from "../model.js";
import { bannersApi } from "./gacha/banners.js";
import { cardsApi } from "./gacha/cards.js";

export const gachaApi = (): Server.Router => {
  const router = Server.router();

  const cards = cardsApi();
  router.use("/cards", cards.routes(), cards.allowedMethods());

  const banners = bannersApi();
  router.use("/banners", banners.routes(), banners.allowedMethods());

  // Get the user's balance.
  router.get("/balance", async (ctx) => {
    const { auth, store } = ctx.server;
    const credential = await auth.requireIdentifyingCredential(ctx);
    const balance = await store.gachaGetBalance(credential);
    ctx.body = Balances.Balance.encode(Balances.fromInternal(balance));
  });

  // Get the context for cards.
  router.get("/context", async (ctx) => {
    const { store } = ctx.server;
    const [rarities, qualities] = await Promise.all([
      store.gachaGetRarities(),
      store.gachaGetQualities(),
    ]);
    ctx.body = Context.encode({
      rarities: rarities.map(Rarities.fromInternal),
      qualities: qualities.map(Qualities.fromInternal),
    });
  });

  return router;
};
