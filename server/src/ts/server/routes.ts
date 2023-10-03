import * as Joda from "@js-joda/core";
import { default as Router } from "@koa/router";
import { promises as fs } from "fs";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Feed } from "../public.js";
import { Arrays } from "../util/arrays.js";
import { Credentials } from "./auth/credentials.js";
import { WebError } from "./errors.js";
import type { Server } from "./model.js";
import { ResultCache } from "./result-cache.js";
import { authApi } from "./routes/auth.js";
import { gachaApi } from "./routes/gacha.js";
import { gamesApi } from "./routes/games.js";
import { leaderboardApi } from "./routes/leaderboard.js";
import { usersApi } from "./routes/users.js";
import { uploadBody } from "./routes/util.js";

export const api = (server: Server.State): Router => {
  const apiRouter = new Router();

  const auth = authApi(server);
  apiRouter.use("/auth", auth.routes(), auth.allowedMethods());
  const users = usersApi(server);
  apiRouter.use("/users", users.routes(), users.allowedMethods());
  const games = gamesApi(server);
  apiRouter.use("/games", games.routes(), games.allowedMethods());
  const leaderboard = leaderboardApi(server);
  apiRouter.use(
    "/leaderboard",
    leaderboard.routes(),
    leaderboard.allowedMethods(),
  );
  const gacha = gachaApi(server);
  apiRouter.use("/gacha", gacha.routes(), gacha.allowedMethods());

  const feedCache = new ResultCache<Feed.Event[]>(
    async () =>
      (await server.store.getFeed()).map((item) => Feed.fromInternal(item)),
    Joda.Duration.of(1, Joda.ChronoUnit.MINUTES),
  );

  apiRouter.get("/feed", async (ctx) => {
    ctx.body = Schema.readonlyArray(Feed.Event).encode(await feedCache.get());
  });

  apiRouter.post("/upload", uploadBody, async (ctx) => {
    const imageUpload = server.imageUpload;
    if (imageUpload !== undefined) {
      const credential = await server.auth.requireIdentifyingCredential(ctx);
      await server.store.validateUpload(credential);
      const files = Arrays.singletonOrArray(ctx.request.files?.["file"]);
      const [file] = files;
      if (files.length > 1 || file === undefined) {
        throw new WebError(
          StatusCodes.BAD_REQUEST,
          "Must include a single file.",
        );
      }
      if (file.mimetype === null) {
        throw new WebError(StatusCodes.BAD_REQUEST, "File type not provided.");
      }
      ctx.body = Schema.strict({ url: Schema.string }).encode({
        url: (
          await imageUpload.upload(
            file.originalFilename ?? file.newFilename,
            file.mimetype,
            Uint8Array.from(await fs.readFile(file.filepath)),
            { uploader: Credentials.actingUser(credential) },
          )
        ).toString(),
      });
    } else {
      throw new WebError(
        StatusCodes.SERVICE_UNAVAILABLE,
        "No file storage available.",
      );
    }
  });

  return apiRouter;
};

export * as Routes from "./routes.js";
