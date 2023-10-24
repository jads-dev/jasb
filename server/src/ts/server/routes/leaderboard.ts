import * as Schema from "io-ts";

import { Leaderboard } from "../../public.js";
import type { Config } from "../config.js";
import { Server } from "../model.js";
import { ResultCache } from "../result-cache.js";

export const leaderboardApi = (config: Config.Server): Server.Router => {
  const router = Server.router();

  const netWorthLeaderboardCache = new ResultCache(
    async (server: Server.State) =>
      (await server.store.getNetWorthLeaderboard()).map(
        Leaderboard.netWorthEntryFromInternal,
      ),
    config.performance.leaderboardCacheDuration,
  );
  router.get("/", async (ctx) => {
    ctx.body = Schema.readonlyArray(Leaderboard.NetWorthEntry).encode(
      await netWorthLeaderboardCache.get(ctx.server),
    );
  });

  const debtLeaderboardCache = new ResultCache(
    async (server: Server.State) =>
      (await server.store.getDebtLeaderboard()).map(
        Leaderboard.debtEntryFromInternal,
      ),
    config.performance.leaderboardCacheDuration,
  );
  router.get("/debt", async (ctx) => {
    ctx.body = Schema.readonlyArray(Leaderboard.DebtEntry).encode(
      await debtLeaderboardCache.get(ctx.server),
    );
  });

  return router;
};
