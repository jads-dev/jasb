import * as Joda from "@js-joda/core";
import * as Schema from "io-ts";

import { Feed } from "../public.js";
import type { Config } from "./config.js";
import { Server } from "./model.js";
import { ResultCache } from "./result-cache.js";
import { authApi } from "./routes/auth.js";
import { gachaApi } from "./routes/gacha.js";
import { gamesApi } from "./routes/games.js";
import { leaderboardApi } from "./routes/leaderboard.js";
import { usersApi } from "./routes/users.js";

export const api = (config: Config.Server): Server.Router => {
  const apiRouter = Server.router();

  const auth = authApi();
  apiRouter.use("/auth", auth.routes(), auth.allowedMethods());
  const users = usersApi();
  apiRouter.use("/users", users.routes(), users.allowedMethods());
  const games = gamesApi(config);
  apiRouter.use("/games", games.routes(), games.allowedMethods());
  const leaderboard = leaderboardApi(config);
  apiRouter.use(
    "/leaderboard",
    leaderboard.routes(),
    leaderboard.allowedMethods(),
  );
  const gacha = gachaApi();
  apiRouter.use("/gacha", gacha.routes(), gacha.allowedMethods());

  const feedCache = new ResultCache(
    async (server: Server.State) =>
      (await server.store.getFeed()).map((item) => Feed.fromInternal(item)),
    Joda.Duration.of(1, Joda.ChronoUnit.MINUTES),
  );

  apiRouter.get("/feed", async (ctx) => {
    ctx.body = Schema.readonlyArray(Feed.Event).encode(
      await feedCache.get(ctx.server),
    );
  });

  return apiRouter;
};

export * as Routes from "./routes.js";
