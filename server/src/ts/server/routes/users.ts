import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { WebSocket } from "ws";

import { Games, Notifications, Users } from "../../public.js";
import { requireUrlParameter, Validation } from "../../util/validation.js";
import { Credentials } from "../auth/credentials.js";
import { WebError } from "../errors.js";
import { Server } from "../model.js";
import { body, validateSearchQuery } from "./util.js";

const PermissionsBody = Schema.readonly(
  Schema.partial({
    game: Games.Slug,
    manageGames: Schema.boolean,
    managePermissions: Schema.boolean,
    manageGacha: Schema.boolean,
    manageBets: Schema.boolean,
  }),
);

export const usersApi = (): Server.Router => {
  const router = Server.router();

  // Get Logged In User.
  router.get("/", async (ctx) => {
    const { auth } = ctx.server;
    const credential = await auth.requireIdentifyingCredential(ctx);
    // We don't actually validate this credential, but this redirect is safe to do anyway, so that's fine.
    ctx.redirect(`/api/user/${Credentials.actingUser(credential)}`);
    ctx.status = StatusCodes.TEMPORARY_REDIRECT;
  });

  // Search for users.
  router.get("/search", async (ctx) => {
    const { store } = ctx.server;
    const query = validateSearchQuery(ctx);
    const summaries = await store.searchUsers(query);
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Users.Slug, Users.Summary]),
    ).encode(summaries.map(Users.summaryFromInternal));
  });

  // Get User.
  router.get("/:userSlug", async (ctx) => {
    const { store } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const internalUser = await store.getUser(userSlug);
    if (internalUser === undefined) {
      throw new WebError(StatusCodes.NOT_FOUND, "User not found.");
    }
    ctx.body = Schema.tuple([Users.Slug, Users.User]).encode(
      Users.fromInternal(internalUser),
    );
  });

  // Get User Bets.
  router.get("/:userSlug/bets", async (ctx) => {
    const { store } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const games = await store.getUserBets(userSlug);
    ctx.body = Schema.readonlyArray(
      Schema.tuple([Games.Slug, Games.WithBets]),
    ).encode(games.map(Games.withBetsFromInternal));
  });

  // Get User Notifications.
  router.get("/:userSlug/notifications", async (ctx) => {
    const { auth, store, webSockets } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const credential = await auth.requireIdentifyingCredential(ctx);
    Credentials.ensureCanActAs(credential, userSlug);

    // If we have a web-socket, the client requested an upgrade to one,
    // so we should do that, otherwise we fall back to just a standard
    // one-time reply.
    const ws: unknown = ctx["ws"];
    if (ws instanceof Function) {
      const socket = (await ws()) as WebSocket;
      const userId = await store.validateCredential(credential);
      await webSockets.attach(
        ctx.server,
        ctx.logger,
        userId,
        credential,
        socket,
      );
    } else {
      const notifications = await store.getNotifications(credential);
      ctx.body = Schema.readonlyArray(Notifications.Notification).encode(
        notifications.map(Notifications.fromInternal),
      );
    }
  });

  // Clear User Notification.
  router.post("/:userSlug/notifications/:notificationId", body, async (ctx) => {
    const { auth, store } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const notificationId = Validation.requireNumberUrlParameter(
      Notifications.Id,
      "notification",
      ctx.params["notificationId"],
    );
    const credential = await auth.requireIdentifyingCredential(ctx);
    Credentials.ensureCanActAs(credential, userSlug);
    await store.clearNotification(credential, notificationId);
    ctx.body = Notifications.Id.encode(notificationId);
  });

  router.get("/:userSlug/bankrupt", async (ctx) => {
    const { store } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    ctx.body = Users.BankruptcyStats.encode(
      Users.bankruptcyStatsFromInternal(await store.bankruptcyStats(userSlug)),
    );
  });

  // Bankrupt User.
  router.post("/:userSlug/bankrupt", async (ctx) => {
    const { auth, store } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const credential = await auth.requireIdentifyingCredential(ctx);
    Credentials.ensureCanActAs(credential, userSlug);
    const internalUser = await store.bankrupt(credential);
    ctx.body = Schema.tuple([Users.Slug, Users.User]).encode(
      Users.fromInternal(internalUser),
    );
  });

  // Get User Permissions.
  router.get("/:userSlug/permissions", async (ctx) => {
    const { store } = ctx.server;
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const permissions = await store.getPermissions(userSlug);
    ctx.body = Users.Permissions.encode(
      Users.permissionsFromInternal(permissions),
    );
  });

  // Set User Permissions.
  router.post("/:userSlug/permissions", body, async (ctx) => {
    const { auth, store } = ctx.server;
    const credential = await auth.requireIdentifyingCredential(ctx);
    const userSlug = requireUrlParameter(
      Users.Slug,
      "user",
      ctx.params["userSlug"],
    );
    const body = Validation.body(PermissionsBody, ctx.request.body);
    const permissions = await store.setPermissions(
      credential,
      userSlug,
      body.game,
      body.manageGames,
      body.managePermissions,
      body.manageGacha,
      body.manageBets,
    );
    ctx.body = Users.Permissions.encode(
      Users.permissionsFromInternal(permissions),
    );
  });

  return router;
};
