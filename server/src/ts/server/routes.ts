import { default as Express } from "express";
import { StatusCodes } from "http-status-codes";
import { Duration } from "luxon";

import { Bets } from "../public/bets";
import { Games } from "../public/games";
import { Leaderboard } from "../public/leaderboard";
import { Notifications } from "../public/notifications";
import { Users } from "../public/users";
import { AsyncIterables } from "../util/async-iterables";
import { Claims } from "./auth";
import { WebError } from "./errors";
import { Server } from "./model";
import { ResultCache } from "./result-cache";

const tokenCookieName = "jasb-token";

const stateCookieName = "jasb-state";

export const api = (server: Server.State): Express.Router => {
  const getClaims = async (
    cookies: Record<string, string>
  ): Promise<Claims> => {
    const token = cookies[tokenCookieName];
    if (token === undefined) {
      throw new WebError(StatusCodes.UNAUTHORIZED, "Not logged in.");
    }
    return await server.auth.validate(token);
  };

  // /api/auth
  const authRouter = Express.Router();
  authRouter.post("/login", async (request, response) => {
    const origin = server.config.clientOrigin;
    if (!request.body.code) {
      const token = request.cookies[tokenCookieName];
      if (token !== undefined) {
        const claims = await server.auth.tryGetClaims(token);
        if (claims !== undefined) {
          const internalUser = await server.store.getUser(claims.uid);
          if (internalUser !== undefined) {
            const result: { id: Users.Id; user: Users.User } = {
              id: claims.uid,
              user: Users.fromInternal(internalUser),
            };
            response.json(result);
            return;
          }
        }
      }
      const { url, state } = await server.auth.redirect(origin);
      response
        .cookie(stateCookieName, state, {
          httpOnly: true,
          sameSite: "strict",
          secure: process.env.NODE_ENV === "production",
        })
        .json({ redirect: url });
    } else {
      const state = request.cookies[stateCookieName];
      if (state === undefined) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Missing state cookie.");
      }
      if (state !== request.body.state) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Incorrect state.");
      }
      const { user, token } = await server.auth.login(
        origin,
        request.body.code
      );
      response
        .clearCookie(stateCookieName)
        .cookie(tokenCookieName, token, {
          maxAge: server.config.auth.tokenLifetime.toMillis(),
          httpOnly: true,
          sameSite: "strict",
          secure: process.env.NODE_ENV === "production",
        })
        .json(user);
    }
  });

  authRouter.post("/logout", async (request, response) => {
    const claims = await getClaims(request.cookies);
    const internalUser = await server.store.getUser(claims.uid);
    if (internalUser !== undefined) {
      await server.auth.logout(internalUser.accessToken);
    }
    response.clearCookie(tokenCookieName).status(StatusCodes.NO_CONTENT).send();
  });

  // /api/user
  const userRouter = Express.Router();
  userRouter.get("/", async (request, response) => {
    const claims = await getClaims(request.cookies);
    response.redirect(
      StatusCodes.TEMPORARY_REDIRECT,
      `/api/user/${claims.uid}`
    );
  });

  userRouter.get("/:userId", async (request, response) => {
    const id = request.params.userId;
    const internalUser = await server.store.getUser(id);
    if (internalUser === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
    }
    const result: { id: Users.Id; user: Users.User } = {
      id,
      user: Users.fromInternal(internalUser),
    };
    response.json(result);
  });

  userRouter.get("/:userId/notifications", async (request, response) => {
    const id = request.params.userId;
    const claims = await getClaims(request.cookies);
    if (claims.uid !== id) {
      throw new WebError(
        StatusCodes.NOT_FOUND,
        "Can't get other user's notifications."
      );
    }
    const notifications = await server.store.getNotifications(claims.uid);
    const result: Notifications.Notification[] = notifications.map(
      Notifications.fromInternal
    );
    response.json(result);
  });

  userRouter.delete("/:userId/notifications", async (request, response) => {
    const id = request.params.userId;
    const claims = await getClaims(request.cookies);
    if (claims.uid !== id) {
      throw new WebError(
        StatusCodes.NOT_FOUND,
        "Can't delete other user's notifications."
      );
    }
    await server.store.clearNotifications(claims.uid);
    response.status(StatusCodes.NO_CONTENT).send();
  });

  userRouter.post("/:userId/bankrupt", async (request, response) => {
    const id = request.params.userId;
    const claims = await getClaims(request.cookies);
    if (claims.uid !== id) {
      throw new WebError(
        StatusCodes.NOT_FOUND,
        "You can't make other players bankrupt."
      );
    }
    await server.store.bankrupt(id);
    const internalUser = await server.store.getUser(id);
    if (internalUser === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
    }
    const result: { id: Users.Id; user: Users.User } = {
      id,
      user: Users.fromInternal(internalUser),
    };
    response.json(result);
  });

  // /api/game
  const gameRouter = Express.Router();
  const gamesCache = new ResultCache<Games.Library>(async () => {
    const future = [];
    const current = [];
    const finished = [];
    for await (const withId of server.store.getGames()) {
      const game = { id: withId.id, game: Games.fromInternal(withId.game) };
      switch (withId.game.progress.state) {
        case "Future":
          future.push(game);
          break;
        case "Current":
          current.push(game);
          break;
        case "Finished":
          finished.push(game);
          break;
        default:
          return Games.unknownProgress(withId.game.progress);
      }
    }
    return { future, current, finished };
  }, Duration.fromObject({ minutes: 1 }));

  gameRouter.get("/", async (request, response) => {
    const result: Games.Library = await gamesCache.get();
    response.json(result);
  });

  gameRouter.get("/:gameId", async (request, response) => {
    const game = await server.store.getGame(request.params.gameId);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const bets = server.store.getBets(request.params.gameId);
    const result: {
      game: Games.Game;
      bets: { id: Bets.Id; bet: Bets.Bet }[];
    } = {
      game: Games.fromInternal(game),
      bets: await AsyncIterables.mapToArray(bets, ({ id, bet }) => ({
        id,
        bet: Bets.fromInternal(bet),
      })),
    };
    response.json(result);
  });

  gameRouter.get("/:gameId/suggestions", async (request, response) => {
    const claims = await getClaims(request.cookies);
    const gameId = request.params.gameId;
    const game = await server.store.getGame(gameId);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const suggestionsBy =
      claims.admin || (claims.mod !== undefined && claims.mod.includes(gameId))
        ? undefined
        : claims.uid;
    const bets = await server.store.getSuggestions(gameId, suggestionsBy);
    const result: {
      game: Games.Game;
      bets: { id: Bets.Id; bet: Bets.Bet }[];
    } = {
      game: Games.fromInternal(game),
      bets: await AsyncIterables.mapToArray(bets, ({ id, bet }) => ({
        id,
        bet: Bets.fromInternal(bet),
      })),
    };
    response.json(result);
  });

  gameRouter.get("/:gameId/:betId", async (request, response) => {
    const game = await server.store.getGame(request.params.gameId);
    if (game === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Game not found.");
    }
    const bet = await server.store.getBet(
      request.params.gameId,
      request.params.betId
    );
    if (bet === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "Bet not found.");
    }
    const result: { game: Games.Game; bet: Bets.Bet } = {
      game: Games.fromInternal(game),
      bet: Bets.fromInternal(bet),
    };
    response.json(result);
  });

  gameRouter.post("/:gameId/:betId/:optionId", async (request, response) => {
    const claims = await getClaims(request.cookies);
    const { amount } = request.body;
    if (amount === undefined || typeof amount !== "number") {
      throw new WebError(StatusCodes.BAD_REQUEST, "No amount given.");
    }
    if (amount < 0) {
      throw new WebError(
        StatusCodes.BAD_REQUEST,
        "Can't bet a negative amount."
      );
    }
    const { bet, user } = await server.store.commitStake(
      claims.uid,
      request.params.gameId,
      request.params.betId,
      request.params.optionId,
      Math.floor(amount)
    );
    const result: { bet: Bets.Bet; user: Users.User } = {
      bet: Bets.fromInternal(bet),
      user: Users.fromInternal(user),
    };
    response.json(result);
  });

  gameRouter.put("/:gameId", async (request, response) => {
    const claims = await getClaims(request.cookies);
    if (claims.admin) {
      const game: Games.Game = request.body;
      if (
        await server.store.setGame(
          request.params.gameId,
          Games.toInternal(game)
        )
      ) {
        response.status(StatusCodes.CREATED).send();
      } else {
        response.status(StatusCodes.OK).send();
      }
    } else {
      throw new WebError(
        StatusCodes.FORBIDDEN,
        "Non-admin tried to perform admin task."
      );
    }
  });

  gameRouter.put("/:gameId/:betId", async (request, response) => {
    const claims = await getClaims(request.cookies);
    const gameId = request.params.gameId;
    if (
      claims.admin === true ||
      (claims.mod !== undefined && claims.mod.includes(request.params.gameId))
    ) {
      const bet: Bets.Bet = request.body;
      if (
        await server.store.setBet(
          gameId,
          request.params.betId,
          Bets.toInternal(bet)
        )
      ) {
        response.status(StatusCodes.CREATED).send();
      } else {
        response.status(StatusCodes.OK).send();
      }
    } else {
      throw new WebError(
        StatusCodes.FORBIDDEN,
        "Non-admin tried to perform admin task."
      );
    }
  });

  // /api
  const apiRouter = Express.Router();
  apiRouter.use("/auth", authRouter);
  apiRouter.use("/user", userRouter);
  apiRouter.use("/game", gameRouter);

  const leaderboardCache = new ResultCache<Leaderboard.Entry[]>(async () => {
    const leaderboard = [];
    for await (const entry of server.store.getUsers()) {
      leaderboard.push(Leaderboard.fromInternal(entry.id, entry.user));
    }
    return leaderboard;
  }, Duration.fromObject({ minutes: 1 }));

  apiRouter.get("/leaderboard", async (request, response) => {
    const result: Leaderboard.Entry[] = await leaderboardCache.get();
    response.json(result);
  });

  // /
  const router = Express.Router();
  router.use("/api", apiRouter);

  return router;
};

export * as Routes from "./routes";
