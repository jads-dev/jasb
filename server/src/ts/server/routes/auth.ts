import * as Joda from "@js-joda/core";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Notifications } from "../../public.js";
import { Users } from "../../public/users.js";
import { Validation } from "../../util/validation.js";
import { Auth } from "../auth.js";
import { WebError } from "../errors.js";
import { Server } from "../model.js";
import { body } from "./util.js";
const secure = process.env["NODE_ENV"] !== "development";

const UserAndNotifications = Schema.strict({
  user: Schema.tuple([Users.Slug, Users.User]),
  notifications: Schema.readonlyArray(Notifications.Notification),
});

const DiscordLoginBody = Schema.strict({
  code: Schema.string,
  state: Schema.string,
});

export const authApi = (server: Server.State): Server.Router => {
  const router = Server.router();

  // Log In.
  router.post("/login", body, async (ctx) => {
    const origin = server.config.clientOrigin;
    const credential = await server.auth.getCredential(ctx);
    if (credential.credential !== "unauthorized") {
      const oldSession = server.auth.requireUserSession(credential);
      const user = await server.store.getUser(oldSession.user);
      if (user !== undefined) {
        const notifications = await server.store.getNotifications(oldSession);
        ctx.body = UserAndNotifications.encode({
          user: Users.fromInternal(user),
          notifications: notifications.map(Notifications.fromInternal),
        });
        return;
      }
    }
    const body = Validation.maybeBody(DiscordLoginBody, ctx.request.body);
    if (body === undefined) {
      const { url, state } = await server.auth.redirect(origin);
      ctx.cookies.set(Auth.stateCookieName, state, {
        maxAge: server.config.auth.stateValidityDuration.toMillis(),
        httpOnly: true,
        sameSite: "strict",
        secure: secure,
        signed: true,
      });
      ctx.body = Schema.strict({ redirect: Schema.string }).encode({
        redirect: url,
      });
      return;
    } else {
      const stateCookie = ctx.cookies.get(Auth.stateCookieName, {
        signed: true,
      });
      if (stateCookie === undefined) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Missing state cookie.");
      }
      const { user, notifications, session, expires } = await server.auth.login(
        server,
        origin,
        stateCookie,
        body.state,
        body.code,
      );
      ctx.cookies.set(Auth.stateCookieName, null, { signed: true });
      ctx.cookies.set(Auth.sessionCookieName, session, {
        expires: Joda.convert(expires).toDate(),
        httpOnly: true,
        sameSite: "strict",
        secure: secure,
        signed: true,
      });
      ctx.body = UserAndNotifications.encode({
        user,
        notifications,
      });
    }
  });

  // Log Out.
  router.post("/logout", body, async (ctx) => {
    const credential = await server.auth.requireIdentifyingCredential(ctx);
    const session = server.auth.requireUserSession(credential);
    await server.auth.logout(server, session.user, session.session);
    ctx.cookies.set(Auth.sessionCookieName, null, { signed: true });
    ctx.body = Users.Slug.encode(session.user);
  });

  return router;
};
