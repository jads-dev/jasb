import * as Joda from "@js-joda/core";
import { default as Router } from "@koa/router";
import type * as Cookies from "cookies";
import { either as Either } from "fp-ts";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Notifications } from "../../public.js";
import { Users } from "../../public/users.js";
import { Validation } from "../../util/validation.js";
import { Auth } from "../auth.js";
import { WebError } from "../errors.js";
import type { Server } from "../model.js";
import { body } from "./util.js";

export const SessionCookie = Schema.strict({
  user: Users.Slug,
  session: Validation.SecretTokenUri,
});
export type SessionCookie = Schema.TypeOf<typeof SessionCookie>;

const UserAndNotifications = Schema.strict({
  user: Schema.tuple([Users.Slug, Users.User]),
  notifications: Schema.readonlyArray(Notifications.Notification),
});

const encodeSessionCookie = (data: SessionCookie): string =>
  JSON.stringify(SessionCookie.encode(data));

export const decodeSessionCookie = (
  cookies: Cookies,
): SessionCookie | undefined => {
  const maybeCookie = cookies.get(Auth.sessionCookieName, { signed: true });
  if (maybeCookie !== undefined) {
    const cookie = decodeURIComponent(maybeCookie);
    const result = SessionCookie.decode(JSON.parse(cookie));
    if (Either.isRight(result)) {
      return result.right;
    } else {
      return undefined;
    }
  } else {
    return undefined;
  }
};

export const requireSession = (cookies: Cookies): SessionCookie => {
  const session = decodeSessionCookie(cookies);
  if (session !== undefined) {
    return session;
  } else {
    throw new WebError(StatusCodes.UNAUTHORIZED, "Must be logged in.");
  }
};

const DiscordLoginBody = Schema.strict({
  code: Schema.string,
  state: Schema.string,
});

export const authApi = (server: Server.State): Router => {
  const router = new Router();

  // Log In.
  router.post("/login", body, async (ctx) => {
    const origin = server.config.clientOrigin;
    const oldSession = decodeSessionCookie(ctx.cookies);
    if (oldSession != null) {
      const user = await server.store.getUser(oldSession.user);
      if (user !== undefined) {
        const notifications = await server.store.getNotifications(
          oldSession.user,
          oldSession.session,
        );
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
        secure: Auth.secure,
        signed: true,
      });
      ctx.body = Schema.strict({ redirect: Schema.string }).encode({
        redirect: url,
      });
      return;
    } else {
      const expectedState = ctx.cookies.get(Auth.stateCookieName, {
        signed: true,
      });
      if (expectedState === undefined) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Missing state cookie.");
      }
      if (expectedState !== body.state) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Incorrect state.");
      }
      const { user, notifications, session, expires } = await server.auth.login(
        origin,
        body.code,
      );
      ctx.cookies.set(Auth.stateCookieName, null, { signed: true });
      ctx.cookies.set(
        Auth.sessionCookieName,
        encodeSessionCookie({ user: user[0], session }),
        {
          expires: Joda.convert(expires).toDate(),
          httpOnly: true,
          sameSite: "strict",
          secure: Auth.secure,
          signed: true,
        },
      );
      ctx.body = UserAndNotifications.encode({
        user,
        notifications,
      });
    }
  });

  // Log Out.
  router.post("/logout", body, async (ctx) => {
    const oldSession = requireSession(ctx.cookies);
    await server.auth.logout(oldSession.user, oldSession.session);
    ctx.cookies.set(Auth.sessionCookieName, null, { signed: true });
    ctx.body = Users.Slug.encode(oldSession.user);
  });

  return router;
};
