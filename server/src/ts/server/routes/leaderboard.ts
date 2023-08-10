import { default as Router } from "@koa/router";
import * as Schema from "io-ts";

import { Leaderboard } from "../../public.js";
import type { Server } from "../model.js";
import { ResultCache } from "../result-cache.js";

export const leaderboardApi = (server: Server.State): Router => {
  const router = new Router();

  const netWorthLeaderboardCache = new ResultCache<Leaderboard.NetWorthEntry[]>(
    async () =>
      (await server.store.getNetWorthLeaderboard()).map(
        Leaderboard.netWorthEntryFromInternal,
      ),
    server.config.performance.leaderboardCacheDuration,
  );
  router.get("/", async (ctx) => {
    ctx.body = Schema.readonlyArray(Leaderboard.NetWorthEntry).encode(
      await netWorthLeaderboardCache.get(),
    );
  });

  const debtLeaderboardCache = new ResultCache<Leaderboard.DebtEntry[]>(
    async () =>
      (await server.store.getDebtLeaderboard()).map(
        Leaderboard.debtEntryFromInternal,
      ),
    server.config.performance.leaderboardCacheDuration,
  );
  router.get("/debt", async (ctx) => {
    ctx.body = Schema.readonlyArray(Leaderboard.DebtEntry).encode(
      await debtLeaderboardCache.get(),
    );
  });

  return router;
};
