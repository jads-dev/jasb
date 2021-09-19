import * as Joda from "@js-joda/core";
import { default as Express } from "express";
import { default as asyncHandler } from "express-async-handler";
import { either as Either } from "fp-ts";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";

import { Notifications, Users } from "../../public";
import { Validation } from "../../util/validation";
import { Auth } from "../auth";
import { WebError } from "../errors";
import { Server } from "../model";

const SessionCookie = Schema.strict({
  user: Users.Id,
  session: Validation.SecretTokenUri,
});
type SessionCookie = Schema.TypeOf<typeof SessionCookie>;

const encodeSessionCookie = (data: SessionCookie): string =>
  JSON.stringify(SessionCookie.encode(data));

export const decodeSessionCookie = (
  cookies: Record<string, string>
): SessionCookie | undefined => {
  const cookie = cookies[Auth.sessionCookieName];
  if (cookie !== undefined) {
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

export const requireSession = (
  cookies: Record<string, string>
): SessionCookie => {
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

export const authApi = (server: Server.State): Express.Router => {
  const router = Express.Router();

  // Log In.
  router.post(
    "/login",
    asyncHandler(async (request, response) => {
      const origin = server.config.clientOrigin;
      const oldSession = decodeSessionCookie(request.cookies);
      if (oldSession != null) {
        const user = await server.store.getUser(oldSession.user);
        if (user !== undefined) {
          const notifications = await server.store.getNotifications(
            oldSession.user,
            oldSession.session
          );
          response
            .json({
              user: Users.fromInternal(user),
              notifications: notifications.map(Notifications.fromInternal),
            })
            .send();
          return;
        }
      }
      const body = Validation.maybeBody(DiscordLoginBody, request.body);
      if (body === undefined) {
        const { url, state } = await server.auth.redirect(origin);
        response
          .cookie(Auth.stateCookieName, state, {
            httpOnly: true,
            sameSite: "strict",
            secure: process.env.NODE_ENV === "production",
          })
          .json({ redirect: url });
      } else {
        const expectedState = request.cookies[Auth.stateCookieName];
        if (expectedState === undefined) {
          throw new WebError(StatusCodes.BAD_REQUEST, "Missing state cookie.");
        }
        if (expectedState !== body.state) {
          throw new WebError(StatusCodes.BAD_REQUEST, "Incorrect state.");
        }
        const { user, notifications, session, expires, isNewUser } =
          await server.auth.login(origin, body.code);
        response
          .clearCookie(Auth.stateCookieName)
          .cookie(
            Auth.sessionCookieName,
            encodeSessionCookie({ user: user.id, session }),
            {
              expires: Joda.convert(expires).toDate(),
              httpOnly: true,
              sameSite: "strict",
              secure: process.env.NODE_ENV === "production",
            }
          )
          .json({
            user,
            notifications,
            ...(isNewUser ? { isNewUser: true } : {}),
          })
          .send();
      }
    })
  );

  // Log Out.
  router.post(
    "/logout",
    asyncHandler(async (request, response) => {
      const oldSession = requireSession(request.cookies);
      await server.auth.logout(oldSession.user, oldSession.session);
      response
        .clearCookie(Auth.sessionCookieName)
        .status(StatusCodes.OK)
        .send();
    })
  );

  return router;
};
