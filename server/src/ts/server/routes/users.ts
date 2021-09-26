import { default as Express } from "express";
import { default as asyncHandler } from "express-async-handler";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Notifications, Users, Games, Bets } from "../../public";
import { Validation } from "../../util/validation";
import { WebError } from "../errors";
import { Server } from "../model";
import { requireSession } from "./auth";

const PermissionsBody = Schema.intersection([
  Schema.strict({
    game: Schema.string,
  }),
  Schema.partial({
    canManageBets: Schema.boolean,
  }),
]);
type PermissionsBody = Schema.TypeOf<typeof PermissionsBody>;

export const usersApi = (server: Server.State): Express.Router => {
  const router = Express.Router();

  // Get Logged In User.
  router.get(
    "/",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      response.redirect(
        StatusCodes.TEMPORARY_REDIRECT,
        `/api/user/${sessionCookie.user}`,
      );
    }),
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
    }),
  );

  // Get User Bets.
  router.get(
    "/:userId/bets",
    asyncHandler(async (request, response) => {
      const id = request.params.userId;
      const games = await server.store.getUserBets(id);
      const result: { id: Games.Id; game: Games.WithBets }[] = games.map(
        Games.withBetsFromInternal,
      );
      response.json(result);
    }),
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
          "Can't get other user's notifications.",
        );
      }
      const notifications = await server.store.getNotifications(
        sessionCookie.user,
        sessionCookie.session,
      );
      const result: Notifications.Notification[] = notifications.map(
        Notifications.fromInternal,
      );
      response.json(result);
    }),
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
          "Can't delete other user's notifications.",
        );
      }
      await server.store.clearNotification(
        sessionCookie.user,
        sessionCookie.session,
        notificationId,
      );
      response.status(StatusCodes.NO_CONTENT).send();
    }),
  );

  router.get(
    "/:userId/bankrupt",
    asyncHandler(async (request, response) => {
      const id = request.params.userId;
      const result = Users.bankruptcyStatsFromInternal(
        await server.store.bankruptcyStats(id),
      );
      response.json(result);
    }),
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
          "You can't make other players bankrupt.",
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
    }),
  );

  // Get User Permissions.
  router.get(
    "/:userId/permissions",
    asyncHandler(async (request, response) => {
      const permissions = await server.store.getPermissions(
        request.params.userId,
      );
      const result: Users.Permissions[] = permissions.map(
        Users.permissionsFromInternal,
      );
      response.json(result);
    }),
  );

  // Set User Permissions.
  router.post(
    "/:userId/permissions",
    asyncHandler(async (request, response) => {
      const sessionCookie = requireSession(request.cookies);
      const body = Validation.body(PermissionsBody, request.body);
      await server.store.setPermissions(
        sessionCookie.user,
        sessionCookie.session,
        request.params.userId,
        body.game,
        body.canManageBets,
      );
      response.status(StatusCodes.NO_CONTENT).send();
    }),
  );

  return router;
};
