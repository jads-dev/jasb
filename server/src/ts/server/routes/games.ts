import * as Joda from "@js-joda/core";
import { default as Express } from "express";
import { default as asyncHandler } from "express-async-handler";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Bets, Games } from "../../public";
import { Validation } from "../../util/validation";
import { WebError } from "../errors";
import { Server } from "../model";
import { ResultCache } from "../result-cache";
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

export const gamesApi = (server: Server.State): Express.Router => {
  const router = Express.Router();

  const gamesCache = new ResultCache<Games.Library>(async () => {
    const games = await Promise.all(
      subsets.map((subset) => server.store.getGames(subset))
    );
    const [future, current, finished] = games.map((subset) =>
      subset.map(Games.fromInternal)
    );
    const library: Games.Library = {
      future: future as Games.WithId[],
      current: current as Games.WithId[],
      finished: finished as Games.WithId[],
    };
    return library;
  }, Joda.Duration.of(1, Joda.ChronoUnit.MINUTES));

  // Get Games.
  router.get(
    "/",
    asyncHandler(async (request, response) => {
      const result: Games.Library = await gamesCache.get();
      response.json(result);
    })
  );

  // Get Game.
  router.get(
    "/:gameId",
    asyncHandler(async (request, response) => {
      const game = await server.store.getGame(request.params.gameId ?? "");
      if (game === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
      }
      const result: Games.Game & Games.Details =
        Games.detailedFromInternal(game).game;
      response.json(result);
    })
  );

  // Get Game with Bets.
  router.get(
    "/:gameId/bets",
    asyncHandler(async (request, response) => {
      const gameId = request.params.gameId ?? "";
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
      response.json(result);
    })
  );

  // Create Game.
  router.put(
    "/:gameId",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const body = Validation.body(CreateGameBody, request.body);
      if (
        await server.store.addGame(
          sessionCookie.user,
          sessionCookie.session,
          request.params.gameId ?? "",
          body.name,
          body.cover,
          body.igdbId,
          body.started !== null ? body.started.toString() : null,
          body.finished !== null ? body.finished.toString() : null
        )
      ) {
        response.status(StatusCodes.OK).send();
      } else {
        throw new WebError(
          StatusCodes.FORBIDDEN,
          "Non-admin tried to perform admin task."
        );
      }
    })
  );

  // Edit Game.
  router.post(
    "/:gameId",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const body = Validation.body(EditGameBody, request.body);
      const game = await server.store.editGame(
        sessionCookie.user,
        sessionCookie.session,
        body.version,
        request.params.gameId ?? "",
        body.name,
        body.cover,
        body.igdbId,
        body.started !== null ? body.started?.toString() : null,
        body.finished !== null ? body.finished?.toString() : null
      );
      const result: Games.Game = Games.fromInternal(game).game;
      response.json(result);
    })
  );

  router.use("/:gameId/bets/:betId", betsApi(server));

  return router;
};
