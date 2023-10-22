import * as Joda from "@js-joda/core";
import * as Schema from "io-ts";

import { Feed } from "../public.js";
import { Server } from "./model.js";
import { ResultCache } from "./result-cache.js";
import { authApi } from "./routes/auth.js";
import { gachaApi } from "./routes/gacha.js";
import { gamesApi } from "./routes/games.js";
import { leaderboardApi } from "./routes/leaderboard.js";
import { usersApi } from "./routes/users.js";

export const api = (server: Server.State): Server.Router => {
  const apiRouter = Server.router();

  const auth = authApi(server);
  apiRouter.use("/auth", auth.routes(), auth.allowedMethods());
  const users = usersApi(server);
  apiRouter.use("/users", users.routes(), users.allowedMethods());
  const games = gamesApi(server);
  apiRouter.use("/games", games.routes(), games.allowedMethods());
  const leaderboard = leaderboardApi(server);
  apiRouter.use(
    "/leaderboard",
    leaderboard.routes(),
    leaderboard.allowedMethods(),
  );
  const gacha = gachaApi(server);
  apiRouter.use("/gacha", gacha.routes(), gacha.allowedMethods());

  const feedCache = new ResultCache<Feed.Event[]>(
    async () =>
      (await server.store.getFeed()).map((item) => Feed.fromInternal(item)),
    Joda.Duration.of(1, Joda.ChronoUnit.MINUTES),
  );

  apiRouter.get("/feed", async (ctx) => {
    ctx.body = Schema.readonlyArray(Feed.Event).encode(await feedCache.get());
  });

  return apiRouter;
};

export * as Routes from "./routes.js";
