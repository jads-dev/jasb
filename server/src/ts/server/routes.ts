import * as Joda from "@js-joda/core";
import { default as Router } from "@koa/router";
import { promises as fs } from "fs";
import { StatusCodes } from "http-status-codes";
import { koaBody as Body } from "koa-body";

import { Feed, Leaderboard } from "../public.js";
import { Arrays } from "../util/arrays.js";
import { WebError } from "./errors.js";
import type { Server } from "./model.js";
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
        const files = Arrays.singletonOrArray(ctx.request.files?.["file"]);
        const [file] = files;
        if (files.length > 1 || file === undefined) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Must include a single file.",
          );
        }
        if (file.mimetype === null) {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "File type not provided.",
          );
        }
        ctx.body = {
          url: await imageUpload.upload(
            file.originalFilename ?? file.newFilename,
            file.mimetype,
            Uint8Array.from(await fs.readFile(file.filepath)),
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

  return apiRouter;
};

export * as Routes from "./routes.js";
