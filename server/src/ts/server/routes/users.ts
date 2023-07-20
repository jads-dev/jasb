import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { koaBody as Body } from "koa-body";

import { Games, Notifications, Users } from "../../public.js";
import { Validation } from "../../util/validation.js";
import { WebError } from "../errors.js";
import type { Server } from "../model.js";
import { requireSession } from "./auth.js";

const PermissionsBody = Schema.readonly(
  Schema.partial({
    game: Games.Id,
    manageGames: Schema.boolean,
    managePermissions: Schema.boolean,
    manageBets: Schema.boolean,
  }),
);
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
    ctx.body = Schema.tuple([Users.Id, Users.User]).encode(
      Users.fromInternal(internalUser),
    );
  });

  // Get User Bets.
  router.get("/:userId/bets", async (ctx) => {
    const id = ctx.params["userId"];
    const games = await server.store.getUserBets(id ?? "");
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Games.Id, Games.WithBets]),
    ).encode(games.map(Games.withBetsFromInternal));
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
    ctx.body = Schema.readonlyArray(Notifications.Notification).encode(
      notifications.map(Notifications.fromInternal),
    );
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
    ctx.body = Users.BankruptcyStats.encode(
      Users.bankruptcyStatsFromInternal(
        await server.store.bankruptcyStats(id ?? ""),
      ),
    );
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
    ctx.body = Schema.tuple([Users.Id, Users.User]).encode(
      Users.fromInternal(internalUser),
    );
  });

  // Get User Permissions.
  router.get("/:userId/permissions", async (ctx) => {
    const permissions = await server.store.getPermissions(
      ctx.params["userId"] ?? "",
    );
    ctx.body = Users.EditablePermissions.encode(
      Users.editablePermissionsFromInternal(permissions),
    );
  });

  // Set User Permissions.
  router.post("/:userId/permissions", Body(), async (ctx) => {
    const sessionCookie = requireSession(ctx.cookies);
    const body = Validation.body(PermissionsBody, ctx.request.body);
    const permissions = await server.store.setPermissions(
      sessionCookie.user,
      sessionCookie.session,
      ctx.params["userId"] ?? "",
      body.game,
      body.manageGames,
      body.managePermissions,
      body.manageBets,
    );
    ctx.body = Users.EditablePermissions.encode(
      Users.editablePermissionsFromInternal(permissions),
    );
  });

  return router;
};
