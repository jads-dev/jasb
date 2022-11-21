import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { koaBody as Body } from "koa-body";

import { Games, Notifications, Users } from "../../public.js";
import { Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";
import type { Server } from "../model.js";
import { requireSession } from "./auth.js";

const PermissionsBody = Schema.intersection([
  Schema.strict({
    game: Schema.string,
  }),
  Schema.partial({
    canManageBets: Schema.boolean,
  }),
]);
type PermissionsBody = Schema.TypeOf<typeof PermissionsBody>;

export const usersApi = (server: Server.State): Router => {
  const router = new Router();

  // Get Logged In User.
  router.get("/", async (ctx) => {
    const sessionCookie = requireSession(ctx["ctx"].cookies);
    ctx.redirect(`/api/user/${sessionCookie.user}`);
    ctx.status = StatusCodes.TEMPORARY_REDIRECT;
  });

  // Get User.
  router.get("/:userId", async (ctx) => {
    const id = ctx.params["userId"];
    const internalUser = await server.store.getUser(id ?? "");
    if (internalUser === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
    }
    const result: Users.WithId = Users.fromInternal(internalUser);
    ctx.body = result;
  });

  // Get User Bets.
  router.get("/:userId/bets", async (ctx) => {
    const id = ctx.params["userId"];
    const games = await server.store.getUserBets(id ?? "");
    const result: { id: Games.Id; game: Games.WithBets }[] = games.map(
      Games.withBetsFromInternal,
    );
    ctx.body = result;
  });

  // Get User Notifications.
  router.get("/:userId/notifications", async (ctx) => {
    const id = ctx.params["userId"];
    const sessionCookie = requireSession(ctx.cookies);
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
    ctx.body = result;
  });

  // Clear User Notification.
  router.post("/:userId/notifications/:notificationId", Body(), async (ctx) => {
    const userId = ctx.params["userId"];
    const notificationId = ctx.params["notificationId"];
    const sessionCookie = requireSession(ctx.cookies);
    if (sessionCookie.user !== userId) {
      throw new WebError(
        StatusCodes.NOT_FOUND,
        "Can't delete other user's notifications.",
      );
    }
    await server.store.clearNotification(
      sessionCookie.user,
      sessionCookie.session,
      notificationId ?? "",
    );
    ctx.status = StatusCodes.NO_CONTENT;
  });

  router.get("/:userId/bankrupt", async (ctx) => {
    const id = ctx.params["userId"];
    const result = Users.bankruptcyStatsFromInternal(
      await server.store.bankruptcyStats(id ?? ""),
    );
    ctx.body = result;
  });

  // Bankrupt User.
  router.post("/:userId/bankrupt", Body(), async (ctx) => {
    const id = ctx.params["userId"];
    const sessionCookie = requireSession(ctx.cookies);
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
    ctx.body = result;
  });

  // Get User Permissions.
  router.get("/:userId/permissions", async (ctx) => {
    const permissions = await server.store.getPermissions(
      ctx.params["userId"] ?? "",
    );
    const result: Users.Permissions[] = permissions.map(
      Users.permissionsFromInternal,
    );
    ctx.body = result;
  });

  // Set User Permissions.
  router.post("/:userId/permissions", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(PermissionsBody, ctx.request.body);
    await server.store.setPermissions(
      sessionCookie.user,
      sessionCookie.session,
      ctx.params["userId"] ?? "",
      body.game,
      body.canManageBets,
    );
    ctx.status = StatusCodes.NO_CONTENT;
  });

  return router;
};
