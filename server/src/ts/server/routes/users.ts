import { default as Express } from "express";
import { default as asyncHandler } from "express-async-handler";
import { StatusCodes } from "http-status-codes";

import { Notifications, Users } from "../../public";
import { WebError } from "../errors";
import { Server } from "../model";
import { requireSession } from "./auth";
import { bankruptcyStatsFromInternal } from "../../public/users";

export const usersApi = (server: Server.State): Express.Router => {
  const router = Express.Router();

  // Get Logged In User.
  router.get(
    "/",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      response.redirect(
        StatusCodes.TEMPORARY_REDIRECT,
        `/api/user/${sessionCookie.user}`
      );
    })
  );

  // Get User.
  router.get(
    "/:userId",
    asyncHandler(async (request, response) => {
      const id = request.params.userId;
      const internalUser = await server.store.getUser(id);
      if (internalUser === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
      }
      const result: Users.WithId = Users.fromInternal(internalUser);
      response.json(result);
    })
  );

  // Get User Notifications.
  router.get(
    "/:userId/notifications",
    asyncHandler(async (request, response) => {
      const id = request.params.userId;
      const sessionCookie = requireSession(request.cookies);
      if (sessionCookie.user !== id) {
        throw new WebError(
          StatusCodes.NOT_FOUND,
          "Can't get other user's notifications."
        );
      }
      const notifications = await server.store.getNotifications(
        sessionCookie.user,
        sessionCookie.session
      );
      const result: Notifications.Notification[] = notifications.map(
        Notifications.fromInternal
      );
      response.json(result);
    })
  );

  // Clear User Notification.
  router.post(
    "/:userId/notifications/:notificationId",
    asyncHandler(async (request, response) => {
      const userId = request.params.userId;
      const notificationId = request.params.notificationId;
      const sessionCookie = requireSession(request.cookies);
      if (sessionCookie.user !== userId) {
        throw new WebError(
          StatusCodes.NOT_FOUND,
          "Can't delete other user's notifications."
        );
      }
      await server.store.clearNotification(
        sessionCookie.user,
        sessionCookie.session,
        notificationId
      );
      response.status(StatusCodes.NO_CONTENT).send();
    })
  );

  // // Get User Bets.
  // router.get("/:userId/bets", asyncHandler(async (request, response) => {
  //   const id = request.params.userId as Users.Id;
  //   const bets = await server.store.getUserBets(id);
  //   const result: {
  //     gameId: Games.Id;
  //     gameName: string;
  //     bet: Bets.Bet;
  //   }[] = bets.map((bet) => ({
  //     gameId: bet.game as Games.Id,
  //     gameName: bet.game_name,
  //     bet: Bets.fromInternalWithUserStakes(id, bet).bet,
  //   }));
  //   response.json(result);
  // }));

  router.get(
    "/:userId/bankrupt",
    asyncHandler(async (request, response) => {
      const id = request.params.userId;
      const result = Users.bankruptcyStatsFromInternal(
        await server.store.bankruptcyStats(id)
      );
      response.json(result);
    })
  );

  // Bankrupt User.
  router.post(
    "/:userId/bankrupt",
    asyncHandler(async (request, response) => {
      const id = request.params.userId;
      const sessionCookie = requireSession(request.cookies);
      if (sessionCookie.user !== id) {
        throw new WebError(
          StatusCodes.NOT_FOUND,
          "You can't make other players bankrupt."
        );
      }
      await server.store.bankrupt(sessionCookie.user, sessionCookie.session);
      const internalUser = await server.store.getUser(id);
      if (internalUser === undefined) {
        throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
      }
      const result: { id: Users.Id; user: Users.User } =
        Users.fromInternal(internalUser);
      response.json(result);
    })
  );

  return router;
};
