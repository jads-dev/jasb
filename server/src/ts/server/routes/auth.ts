import * as Joda from "@js-joda/core";
import { default as Router } from "@koa/router";
import type * as Cookies from "cookies";
import { either as Either } from "fp-ts";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import { default as Body } from "koa-body";

import { Notifications, Users } from "../../public.js";
import { Validation } from "../../util/validation.js";
import { Auth } from "../auth.js";
import { WebError } from "../errors.js";
import { Server } from "../model.js";

const SessionCookie = Schema.strict({
  user: Users.Id,
  session: Validation.SecretTokenUri,
});
type SessionCookie = Schema.TypeOf<typeof SessionCookie>;

const encodeSessionCookie = (data: SessionCookie): string =>
  JSON.stringify(SessionCookie.encode(data));

export const decodeSessionCookie = (
  cookies: Cookies,
): SessionCookie | undefined => {
  const maybeCookie = cookies.get(Auth.sessionCookieName);
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
  router.post("/login", Body(), async (ctx) => {
    const origin = server.config.clientOrigin;
    const oldSession = decodeSessionCookie(ctx.cookies);
    if (oldSession != null) {
      const user = await server.store.getUser(oldSession.user);
      if (user !== undefined) {
        const notifications = await server.store.getNotifications(
          oldSession.user,
          oldSession.session,
        );
        ctx.body = {
          user: Users.fromInternal(user),
          notifications: notifications.map(Notifications.fromInternal),
        };
        return;
      }
    }
    const body = Validation.maybeBody(DiscordLoginBody, ctx.request.body);
    if (body === undefined) {
      const { url, state } = await server.auth.redirect(origin);
      ctx.cookies.set(Auth.stateCookieName, state, {
        httpOnly: true,
        sameSite: "strict",
        secure: process.env.NODE_ENV === "production",
      });
      ctx.body = { redirect: url };
      return;
    } else {
      const expectedState = ctx.cookies.get(Auth.stateCookieName);
      if (expectedState === undefined) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Missing state cookie.");
      }
      if (expectedState !== body.state) {
        throw new WebError(StatusCodes.BAD_REQUEST, "Incorrect state.");
      }
      const { user, notifications, session, expires, isNewUser } =
        await server.auth.login(origin, body.code);
      ctx.cookies.set(Auth.stateCookieName, null);
      ctx.cookies.set(
        Auth.sessionCookieName,
        encodeSessionCookie({ user: user.id, session }),
        {
          expires: Joda.convert(expires).toDate(),
          httpOnly: true,
          sameSite: "strict",
          secure: process.env.NODE_ENV === "production",
        },
      );
      ctx.body = {
        user,
        notifications,
        ...(isNewUser ? { isNewUser: true } : {}),
      };
    }
  });

  // Log Out.
  router.post("/logout", Body(), async (ctx) => {
    const oldSession = requireSession(ctx.cookies);
    await server.auth.logout(oldSession.user, oldSession.session);
    ctx.cookies.set(Auth.sessionCookieName, "");
    ctx.status = StatusCodes.OK;
  });

  return router;
};
