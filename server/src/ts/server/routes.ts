import * as Joda from "@js-joda/core";
import { default as Router } from "@koa/router";
import { promises as fs } from "fs";
import { StatusCodes } from "http-status-codes";
import { default as Body } from "koa-body";

import { Feed, Leaderboard } from "../public.js";
import { WebError } from "./errors.js";
import { Server } from "./model.js";
import { ResultCache } from "./result-cache.js";
import { authApi, requireSession } from "./routes/auth.js";
import { gamesApi } from "./routes/games.js";
import { usersApi } from "./routes/users.js";

export const api = (server: Server.State): Router => {
  const apiRouter = new Router();

  const auth = authApi(server);
  apiRouter.use("/auth", auth.routes(), auth.allowedMethods());
  const users = usersApi(server);
  apiRouter.use("/users", users.routes(), users.allowedMethods());
  const games = gamesApi(server);
  apiRouter.use("/games", games.routes(), games.allowedMethods());

  const leaderboardCache = new ResultCache<Leaderboard.Entry[]>(async () => {
    const leaderboard = await server.store.getLeaderboard();
    return leaderboard.map(Leaderboard.fromInternal);
  }, Joda.Duration.of(1, Joda.ChronoUnit.MINUTES));

  apiRouter.get("/leaderboard", async (ctx) => {
    const result: Leaderboard.Entry[] = await leaderboardCache.get();
    ctx.body = result;
  });

  const feedCache = new ResultCache<Feed.Event[]>(
    async () =>
      (await server.store.getFeed()).map((item) => Feed.fromInternal(item)),
    Joda.Duration.of(1, Joda.ChronoUnit.MINUTES),
  );

  apiRouter.get("/feed", async (ctx) => {
    const result: Feed.Event[] = await feedCache.get();
    ctx.body = result;
  });

  apiRouter.post(
    "/upload",
    Body({
      json: false,
      text: false,
      multipart: true,
      formidable: { maxFileSize: 25 * 1024 * 1024 },
    }),
    async (ctx) => {
      const imageUpload = server.imageUpload;
      if (imageUpload !== undefined) {
        const sessionCookie = requireSession(ctx.cookies);
        const userId = await server.store.validateAdminOrMod(
          sessionCookie.user,
          sessionCookie.session,
        );
        const files = ctx.request.files;
        if (
          files === undefined ||
          (Array.isArray(files) && files.length !== 1)
        ) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Must include (single) file.",
          );
        }
        const { file } = Array.isArray(files) ? files[0] : files;
        ctx.body = {
          url: await imageUpload.upload(
            file.name,
            file.type,
            Uint8Array.from(await fs.readFile(file.path)),
            { uploader: userId },
          ),
        };
      } else {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "No file storage available.",
        );
      }
    },
  );

  const clientOrigin = server.config.clientOrigin;
  const regex = new RegExp(
    clientOrigin.replace(/[.*+?^${}()|[\]]/g, "\\$&") +
      "/games/(?<game>[^/]+)(?:/(?<bet>[^/]+)/?)?",
  );
  const titleFor = async (
    gameId: string,
    betId: string | undefined,
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
  apiRouter.get("/embed.json", async (ctx) => {
    const url = ctx.query.url;
    if (url === undefined || typeof url !== "string") {
      throw new WebError(StatusCodes.NOT_FOUND, "No embed for this resource.");
    } else {
      const groups = regex.exec(url)?.groups;
      if (groups === null || groups === undefined) {
        throw new WebError(
          StatusCodes.NOT_FOUND,
          "No embed for this resource.",
        );
      }
      const { game, bet } = groups;
      const result = {
        type: "link",
        version: "1.0",
        title: `Stream Bets: ${await titleFor(game ?? "", bet)}.`,
        provider_name: "JASB",
        provider_url: clientOrigin,
        thumbnail_url: `${clientOrigin}/assets/images/favicon-48x48.png`,
        thumbnail_width: 48,
        thumbnail_height: 48,
      };
      ctx.body = result;
    }
  });

  return apiRouter;
};

export * as Routes from "./routes.js";
