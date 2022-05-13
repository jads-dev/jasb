import * as Joda from "@js-joda/core";
import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { default as Body } from "koa-body";

import { Bets, Games } from "../../public.js";
import { Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";
import { Server } from "../model.js";
import { ResultCache } from "../result-cache.js";
import { requireSession } from "./auth.js";
import { betsApi } from "./bets.js";

const subsets = ["Future", "Current", "Finished"] as const;

const GameBody = {
  name: Schema.string,
  cover: Schema.string,
  igdbId: Schema.string,
  started: Schema.union([Validation.Date, Schema.null]),
  finished: Schema.union([Validation.Date, Schema.null]),
};
const CreateGameBody = Schema.strict(GameBody);
const EditGameBody = Schema.intersection([
  Schema.partial(GameBody),
  Schema.strict({ version: Schema.Int }),
]);

export const gamesApi = (server: Server.State): Router => {
  const router = new Router();

  const gamesCache = new ResultCache<Games.Library>(async () => {
    const games = await Promise.all(
      subsets.map((subset) => server.store.getGames(subset)),
    );
    const [future, current, finished] = games.map((subset) =>
      subset.map(Games.fromInternal),
    );
    const library: Games.Library = {
      future: future as Games.WithId[],
      current: current as Games.WithId[],
      finished: finished as Games.WithId[],
    };
    return library;
  }, Joda.Duration.of(1, Joda.ChronoUnit.MINUTES));

  // Get Games.
  router.get("/", async (ctx) => {
    const result: Games.Library = await gamesCache.get();
    ctx.body = result;
  });

  // Get Game.
  router.get("/:gameId", async (ctx) => {
    const game = await server.store.getGame(ctx.params.gameId ?? "");
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const result: Games.Game & Games.Details =
      Games.detailedFromInternal(game).game;
    ctx.body = result;
  });

  // Get Game with Bets.
  router.get("/:gameId/bets", async (ctx) => {
    const gameId = ctx.params.gameId ?? "";
    const [game, bets] = await Promise.all([
      server.store.getGame(gameId),
      server.store.getBets(gameId),
    ]);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const result: {
      game: Games.Game & Games.Details;
      bets: { id: Bets.Id; bet: Bets.Bet }[];
    } = {
      game: Games.detailedFromInternal(game).game,
      bets: bets.map(Bets.fromInternal),
    };
    ctx.body = result;
  });

  // Get lock status of bets.
  router.get("/:gameId/bets/lock", async (ctx) => {
    const gameId = ctx.params.gameId ?? "";
    const betsLockStatus = await server.store.getBetsLockStatus(gameId);
    const result: Bets.LockStatus[] = betsLockStatus.map(
      Bets.lockStatusFromInternal,
    );
    ctx.body = result;
  });

  // Create Game.
  router.put("/:gameId", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(CreateGameBody, ctx.request.body);
    if (
      await server.store.addGame(
        sessionCookie.user,
        sessionCookie.session,
        ctx.params.gameId ?? "",
        body.name,
        body.cover,
        body.igdbId,
        body.started !== null ? body.started.toString() : null,
        body.finished !== null ? body.finished.toString() : null,
      )
    ) {
      ctx.status = StatusCodes.OK;
    } else {
      throw new WebError(
        StatusCodes.FORBIDDEN,
        "Non-admin tried to perform admin task.",
      );
    }
  });

  // Edit Game.
  router.post("/:gameId", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(EditGameBody, ctx.request.body);
    const game = await server.store.editGame(
      sessionCookie.user,
      sessionCookie.session,
      body.version,
      ctx.params.gameId ?? "",
      body.name,
      body.cover,
      body.igdbId,
      body.started !== null ? body.started?.toString() : null,
      body.finished !== null ? body.finished?.toString() : null,
    );
    const result: Games.Game = Games.fromInternal(game).game;
    ctx.body = result;
  });

  const bets = betsApi(server);
  router.use("/:gameId/bets/:betId", bets.routes(), bets.allowedMethods());

  return router;
};
