import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { koaBody as Body } from "koa-body";

import { Internal } from "../../internal.js";
import { Editor, Games } from "../../public.js";
import { Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";
import type { Server } from "../model.js";
import { ResultCache } from "../result-cache.js";
import { requireSession } from "./auth.js";
import { betsApi } from "./bets.js";

const GameBody = {
  name: Schema.string,
  cover: Schema.string,
  started: Schema.union([Validation.Date, Schema.null]),
  finished: Schema.union([Validation.Date, Schema.null]),
  order: Schema.union([Schema.Int, Schema.null]),
};
const CreateGameBody = Schema.strict(GameBody);
const EditGameBody = Schema.intersection([
  Schema.partial(GameBody),
  Schema.strict({ version: Schema.Int }),
]);

const LockMomentBody = {
  name: Schema.string,
  order: Schema.Int,
};
const EditLockMomentBody = Schema.partial({
  remove: Schema.readonlyArray(
    Schema.strict({
      id: Schema.string,
      version: Schema.Int,
    }),
  ),
  edit: Schema.readonlyArray(
    Schema.intersection([
      Schema.partial(LockMomentBody),
      Schema.strict({
        id: Schema.string,
        version: Schema.Int,
      }),
    ]),
  ),
  add: Schema.readonlyArray(
    Schema.intersection([
      Schema.strict(LockMomentBody),
      Schema.strict({
        id: Schema.string,
      }),
    ]),
  ),
});

export const gamesApi = (server: Server.State): Router => {
  const router = new Router();

  const gamesCache = new ResultCache<Games.Library>(async () => {
    const getGames = async (subset: Internal.Games.Progress) =>
      (await server.store.getGames(subset)).map(Games.withBetStatsFromInternal);
    const [future, current, finished] = await Promise.all([
      getGames("Future"),
      getGames("Current"),
      getGames("Finished"),
    ]);
    return {
      future,
      current,
      finished,
    };
  }, server.config.performance.gamesCacheDuration);

  // Get Games.
  router.get("/", async (ctx) => {
    ctx.body = Games.Library.encode(await gamesCache.get());
  });

  // Get Game.
  router.get("/:gameId", async (ctx) => {
    const game = await server.store.getGame(ctx.params["gameId"] ?? "");
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    ctx.body = Games.WithBetStats.encode(
      Games.withBetStatsFromInternal(game)[1],
    );
  });

  // Get Game with Bets.
  router.get("/:gameId/bets", async (ctx) => {
    const gameId = ctx.params["gameId"] ?? "";
    const [game, bets] = await Promise.all([
      server.store.getGame(gameId),
      server.store.getBets(gameId),
    ]);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    ctx.body = Games.WithBets.encode(
      Games.withBetsFromInternal({ ...game, bets: [...bets] })[1],
    );
  });

  // Get lock status of bets.
  router.get("/:gameId/lock/status", async (ctx) => {
    const gameId = ctx.params["gameId"] ?? "";
    const [lockMoments, betLockStatuses] = await Promise.all([
      server.store.getLockMoments(gameId),
      server.store.getBetsLockStatus(gameId),
    ]);
    ctx.body = Editor.LockMoments.GameLockStatus.encode(
      Editor.LockMoments.gameLockStatusFromInternal(
        lockMoments,
        betLockStatuses,
      ),
    );
  });

  // Get lock moments.
  router.get("/:gameId/lock", async (ctx) => {
    const gameId = ctx.params["gameId"] ?? "";
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Editor.LockMoments.Id, Editor.LockMoments.LockMoment]),
    ).encode(
      (await server.store.getLockMoments(gameId)).map(
        Editor.LockMoments.fromInternal,
      ),
    );
  });

  // Edit lock moments.
  router.post("/:gameId/lock", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const gameId = ctx.params["gameId"] ?? "";
    console.log(ctx.request);
    const body = Validation.body(EditLockMomentBody, ctx.request.body);
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Editor.LockMoments.Id, Editor.LockMoments.LockMoment]),
    ).encode(
      (
        await server.store.editLockMoments(
          sessionCookie.user,
          sessionCookie.session,
          gameId,
          body.remove,
          body.edit,
          body.add,
        )
      ).map(Editor.LockMoments.fromInternal),
    );
  });

  // Create Game.
  router.put("/:gameId", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(CreateGameBody, ctx.request.body);
    const game = await server.store.addGame(
      sessionCookie.user,
      sessionCookie.session,
      ctx.params["gameId"] ?? "",
      body.name,
      body.cover,
      body.started,
      body.finished,
      body.order,
    );
    ctx.body = Games.Game.encode(Games.fromInternal(game)[1]);
  });

  // Edit Game.
  router.post("/:gameId", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(EditGameBody, ctx.request.body);
    const game = await server.store.editGame(
      sessionCookie.user,
      sessionCookie.session,
      body.version,
      ctx.params["gameId"] ?? "",
      body.name,
      body.cover,
      body.started,
      body.finished,
      body.order,
    );
    ctx.body = Games.Game.encode(Games.withBetStatsFromInternal(game)[1]);
  });

  const bets = betsApi(server);
  router.use("/:gameId/bets/:betId", bets.routes(), bets.allowedMethods());

  return router;
};
