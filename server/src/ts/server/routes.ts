import * as Joda from "@js-joda/core";
import { default as Express } from "express";
import { default as asyncHandler } from "express-async-handler";
import { StatusCodes } from "http-status-codes";

import { Feed, Leaderboard } from "../public";
import { WebError } from "./errors";
import { Server } from "./model";
import { ResultCache } from "./result-cache";
import { authApi, requireSession } from "./routes/auth";
import { gamesApi } from "./routes/games";
import { usersApi } from "./routes/users";

export const api = (server: Server.State): Express.Router => {
  const apiRouter = Express.Router();
  apiRouter.use("/auth", authApi(server));
  apiRouter.use("/users", usersApi(server));
  apiRouter.use("/games", gamesApi(server));

  const leaderboardCache = new ResultCache<Leaderboard.Entry[]>(async () => {
    const leaderboard = await server.store.getLeaderboard();
    return leaderboard.map(Leaderboard.fromInternal);
  }, Joda.Duration.of(1, Joda.ChronoUnit.MINUTES));

  apiRouter.get(
    "/leaderboard",
    asyncHandler(async (request, response) => {
      const result: Leaderboard.Entry[] = await leaderboardCache.get();
      response.json(result);
    })
  );

  const feedCache = new ResultCache<Feed.Event[]>(
    async () =>
      (await server.store.getFeed()).map((item) => Feed.fromInternal(item)),
    Joda.Duration.of(1, Joda.ChronoUnit.MINUTES)
  );

  apiRouter.get(
    "/feed",
    asyncHandler(async (request, response) => {
      const result: Feed.Event[] = await feedCache.get();
      response.json(result);
    })
  );

  apiRouter.post(
    "/upload",
    asyncHandler(async (request, response) => {
      if (server.objectUploader.supported) {
        const sessionCookie = requireSession(request.cookies);
        const userId = await server.store.validateAdminOrMod(
          sessionCookie.user,
          sessionCookie.session
        );
        const file = request.files?.file;
        if (file === undefined || Array.isArray(file)) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Must include (single) file."
          );
        }
        response.json({
          url: await server.objectUploader.upload(
            userId,
            file.name,
            file.data,
            file.mimetype,
            file.md5
          ),
        });
      } else {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "No file storage available."
        );
      }
    })
  );

  const clientOrigin = server.config.clientOrigin;
  const regex = new RegExp(
    clientOrigin.replace(/[.*+?^${}()|[\]]/g, "\\$&") +
      "/games/(?<game>[^/]+)(?:/(?<bet>[^/]+)/?)?"
  );
  const titleFor = async (
    gameId: string,
    betId: string | undefined
  ): Promise<string> => {
    const names = await server.store.getTile(gameId, betId ?? null);
    if (names === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "No such game.");
    } else {
      const gameName = names.game_name;
      const betName = names.bet_name;
      if (betId !== undefined) {
        if (betName === null) {
          throw new WebError(StatusCodes.NOT_FOUND, "No such bet.");
        } else {
          return `“${betName}” bet for ${gameName}`;
        }
      } else {
        return `Bets for ${gameName}`;
      }
    }
  };
  apiRouter.get(
    "/embed.json",
    asyncHandler(async (request, response) => {
      const url = request.query.url;
      if (url === undefined || typeof url !== "string") {
        throw new WebError(
          StatusCodes.NOT_FOUND,
          "No embed for this resource."
        );
      } else {
        const groups = regex.exec(url)?.groups;
        if (groups === null || groups === undefined) {
          throw new WebError(
            StatusCodes.NOT_FOUND,
            "No embed for this resource."
          );
        }
        const { game, bet } = groups;
        const result = {
          type: "link",
          version: "1.0",
          title: `Stream Bets: ${await titleFor(game, bet)}.`,
          provider_name: "JASB",
          provider_url: clientOrigin,
          thumbnail_url: `${clientOrigin}/assets/images/favicon-48x48.png`,
          thumbnail_width: 48,
          thumbnail_height: 48,
        };
        response.json(result);
      }
    })
  );

  const router = Express.Router();
  router.use("/api", apiRouter);

  return router;
};

export * as Routes from "./routes";
