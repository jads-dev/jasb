import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Objects } from "../../data/objects.js";
import { Internal } from "../../internal.js";
import { Editor, Games } from "../../public.js";
import { requireUrlParameter, Validation } from "../../util/validation.js";
import type { Config } from "../config.js";
import { WebError } from "../errors.js";
import { Server } from "../model.js";
import { ResultCache } from "../result-cache.js";
import { betsApi } from "./bets.js";
import { body, uploadBody, validateSearchQuery } from "./util.js";

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
      id: Editor.LockMoments.Slug,
      version: Schema.Int,
    }),
  ),
  edit: Schema.readonlyArray(
    Schema.intersection([
      Schema.partial(LockMomentBody),
      Schema.strict({
        id: Editor.LockMoments.Slug,
        version: Schema.Int,
      }),
    ]),
  ),
  add: Schema.readonlyArray(
    Schema.intersection([
      Schema.strict(LockMomentBody),
      Schema.strict({
        id: Editor.LockMoments.Slug,
      }),
    ]),
  ),
});

export const gamesApi = (config: Config.Server): Server.Router => {
  const router = Server.router();

  const gamesCache = new ResultCache(async (server: Server.State) => {
    const getGames = async (subset: Internal.Games.Progress) =>
      (await server.store.getGames(subset)).map(Games.fromInternal);
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
  }, config.performance.gamesCacheDuration);

  // Get Games.
  router.get("/", async (ctx) => {
    ctx.body = Games.Library.encode(await gamesCache.get(ctx.server));
  });

  // Search for games.
  router.get("/search", async (ctx) => {
    const { store } = ctx.server;
    const query = validateSearchQuery(ctx);
    const summaries = await store.searchGames(query);
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Games.Slug, Games.Summary]),
    ).encode(summaries.map(Games.summaryFromInternal));
  });

  // Upload a cover.
  router.post(
    "/cover",
    uploadBody,
    Objects.uploadHandler(Objects.gameCoverTypeProcess),
  );

  // Upload an option image.
  router.post(
    "/options/image",
    uploadBody,
    Objects.uploadHandler(Objects.optionImageProcess),
  );

  // Get Game.
  router.get("/:gameSlug", async (ctx) => {
    const { store } = ctx.server;
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    const internalGame = await store.getGame(gameSlug);
    if (internalGame === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const [, game] = Games.fromInternal(internalGame);
    ctx.body = Games.Game.encode(game);
  });

  // Get Game with Bets.
  router.get("/:gameSlug/bets", async (ctx) => {
    const { store } = ctx.server;
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    const [internalGame, internalBets] = await Promise.all([
      store.getGame(gameSlug),
      store.getBets(gameSlug),
    ]);
    if (internalGame === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const [, gameWithBets] = Games.withBetsFromInternal({
      ...internalGame,
      bets: [...internalBets],
    });
    ctx.body = Games.WithBets.encode(gameWithBets);
  });

  // Get lock status of bets.
  router.get("/:gameSlug/lock/status", async (ctx) => {
    const { store } = ctx.server;
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    const [lockMoments, betLockStatuses] = await Promise.all([
      store.getLockMoments(gameSlug),
      store.getBetsLockStatus(gameSlug),
    ]);
    ctx.body = Editor.LockMoments.GameLockStatus.encode(
      Editor.LockMoments.gameLockStatusFromInternal(
        lockMoments,
        betLockStatuses,
      ),
    );
  });

  // Get lock moments.
  router.get("/:gameSlug/lock", async (ctx) => {
    const { store } = ctx.server;
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Editor.LockMoments.Slug, Editor.LockMoments.LockMoment]),
    ).encode(
      (await store.getLockMoments(gameSlug)).map(
        Editor.LockMoments.fromInternal,
      ),
    );
  });

  // Edit lock moments.
  router.post("/:gameSlug/lock", body, async (ctx) => {
    const { auth, store } = ctx.server;
    const credential = await auth.requireIdentifyingCredential(ctx);
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    const body = Validation.body(EditLockMomentBody, ctx.request.body);
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Editor.LockMoments.Slug, Editor.LockMoments.LockMoment]),
    ).encode(
      (
        await store.editLockMoments(
          credential,
          gameSlug,
          body.remove,
          body.edit,
          body.add,
        )
      ).map(Editor.LockMoments.fromInternal),
    );
  });

  // Create Game.
  router.put("/:gameSlug", body, async (ctx) => {
    const { auth, store } = ctx.server;
    const credential = await auth.requireIdentifyingCredential(ctx);
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    const body = Validation.body(CreateGameBody, ctx.request.body);
    await store.addGame(
      credential,
      gameSlug,
      body.name,
      body.cover,
      body.started,
      body.finished,
      body.order,
    );
    const game = await store.getGame(gameSlug);
    if (game === undefined) {
      throw new Error("Should exist.");
    }
    ctx.body = Games.Game.encode(Games.fromInternal(game)[1]);
  });

  // Edit Game.
  router.post("/:gameSlug", body, async (ctx) => {
    const { auth, store } = ctx.server;
    const credential = await auth.requireIdentifyingCredential(ctx);
    const gameSlug = requireUrlParameter(
      Games.Slug,
      "game",
      ctx.params["gameSlug"],
    );
    const body = Validation.body(EditGameBody, ctx.request.body);
    await store.editGame(
      credential,
      body.version,
      gameSlug,
      body.name,
      body.cover,
      body.started,
      body.finished,
      body.order,
    );
    const game = await store.getGame(gameSlug);
    if (game === undefined) {
      throw new Error("Should exist.");
    }
    ctx.body = Games.Game.encode(Games.fromInternal(game)[1]);
  });

  const bets = betsApi();
  router.use("/:gameSlug/bets/:betSlug", bets.routes(), bets.allowedMethods());

  return router;
};
