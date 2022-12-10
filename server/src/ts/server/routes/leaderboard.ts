import { default as Router } from "@koa/router";

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
  router.get("/net-worth", async (ctx) => {
    const result: Leaderboard.NetWorthEntry[] =
      await netWorthLeaderboardCache.get();
    ctx.body = result;
  });

  const debtLeaderboardCache = new ResultCache<Leaderboard.DebtEntry[]>(
    async () =>
      (await server.store.getDebtLeaderboard()).map(
        Leaderboard.debtEntryFromInternal,
      ),
    server.config.performance.leaderboardCacheDuration,
  );
  router.get("/debt", async (ctx) => {
    const result: Leaderboard.DebtEntry[] = await debtLeaderboardCache.get();
    ctx.body = result;
  });

  return router;
};
