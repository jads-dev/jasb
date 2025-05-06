import * as OAuth from "@badgateway/oauth2-client";
import * as Joda from "@js-joda/core";
import { Instant } from "@js-joda/core";
import { either as Either } from "fp-ts";
import { StatusCodes } from "http-status-codes";
import * as Schema from "io-ts";
import * as Jose from "jose";

import { Discord } from "../external.js";
import { Notifications, Users } from "../public.js";
import { Expect } from "../util/expect.js";
import { Maths } from "../util/maths.js";
import { SecretToken } from "../util/secret-token.js";
import { SecureRandom } from "../util/secure-random.js";
import { Validation } from "../util/validation.js";
import type { Credential, Credentials } from "./auth/credentials.js";
import type { Config } from "./config.js";
import { WebError } from "./errors.js";
import type { Logging } from "./logging.js";
import type { Server } from "./model.js";

export interface DiscordToken {
  accessToken: string;
  refreshToken: string;
  expiresAt: Joda.Instant;
}

export const ExternalServiceToken = Schema.strict({
  iss: Schema.string,
  sub: Users.Slug,
  aud: Schema.string,
  nonce: Schema.string,
  iat: Validation.EpochSeconds,
});
export type ExternalServiceToken = Schema.TypeOf<typeof ExternalServiceToken>;

export const SessionCookie = Schema.strict({
  user: Users.Slug,
  session: Validation.SecretTokenUri,
  nonce: Schema.string,
  iat: Validation.EpochSeconds,
});
export type SessionCookie = Schema.TypeOf<typeof SessionCookie>;

const State = Schema.readonly(
  Schema.strict({
    state: Schema.string,
    code: Schema.string,
    nonce: Schema.string,
    iat: Validation.EpochSeconds,
  }),
);
type State = Schema.TypeOf<typeof State>;

const secure = process.env["NODE_ENV"] !== "development";

interface ResolvedExternalServices {
  config: Config.ExternalServices;
  recognised: Map<string, Jose.CryptoKey | Uint8Array>;
}

const avatarSuffix = (
  userId: string,
  discriminator: string | null,
  avatar: string | null,
  guildId: string,
  guildAvatar: string | null,
): string => {
  if (guildAvatar !== null) {
    return `guilds/${guildId}/users/${userId}/avatars/${guildAvatar}.webp`;
  } else if (avatar !== null) {
    return `avatars/${userId}/${avatar}.png`;
  } else if (discriminator === null) {
    return `embed/avatars/${Maths.modulo(
      Number(BigInt(userId) >> 22n),
      6,
    )}.png`;
  } else {
    return `embed/avatars/${Maths.modulo(parseInt(discriminator, 10), 5)}.png`;
  }
};
const avatar = (
  userId: string,
  discriminator: string | null,
  avatar: string | null,
  guildId: string,
  guildAvatar: string | null,
) =>
  `https://cdn.discordapp.com/${avatarSuffix(
    userId,
    discriminator,
    avatar,
    guildId,
    guildAvatar,
  )}`;

export class Auth {
  static readonly discordBase = "https://discord.com/api/v10";
  static readonly redirectPath = "/auth";
  static readonly sessionCookieName = `${secure ? "__Host-" : ""}jasb-session`;
  static readonly stateCookieName = `${secure ? "__Host-" : ""}jasb-state`;

  readonly #config: Config.Auth;
  readonly #client: OAuth.OAuth2Client;
  readonly #externalServices: ResolvedExternalServices | undefined;

  private constructor(
    config: Config.Auth,
    externalServices: ResolvedExternalServices | undefined,
  ) {
    this.#config = config;
    this.#client = new OAuth.OAuth2Client({
      server: "https://discord.com/oauth2",
      clientId: this.#config.discord.clientId,
      clientSecret: this.#config.discord.clientSecret.value,
      tokenEndpoint: "/api/oauth2/token",
      authorizationEndpoint: "/oauth2/authorize",
    });
    this.#externalServices = externalServices;
  }

  static async #externalServicesResolve(
    config: Config.ExternalServices,
  ): Promise<ResolvedExternalServices> {
    const recognised = new Map(
      await Promise.all(
        Object.entries(config.recognised).map(
          async ([issuer, { publicKey }]): Promise<
            [string, Jose.CryptoKey | Uint8Array]
          > => [issuer, await Jose.importJWK(publicKey, "EdDSA")],
        ),
      ),
    );
    return {
      config,
      recognised,
    };
  }

  static async init(config: Config.Auth): Promise<Auth> {
    return new Auth(
      config,
      config.externalServices !== undefined
        ? await Auth.#externalServicesResolve(config.externalServices)
        : undefined,
    );
  }

  protectedHeader(): { alg: string; enc: string } {
    return { alg: "dir", enc: this.#config.algorithm };
  }

  async #encrypt(payload: Jose.JWTPayload): Promise<string> {
    return await new Jose.EncryptJWT(payload)
      .setProtectedHeader(this.protectedHeader())
      .encrypt(this.#config.key.value);
  }

  async #decrypt(
    ciphertext: string,
  ): Promise<Jose.JWTDecryptResult | undefined> {
    try {
      const { alg, enc } = this.protectedHeader();
      return await Jose.jwtDecrypt(ciphertext, this.#config.key.value, {
        keyManagementAlgorithms: [alg],
        contentEncryptionAlgorithms: [enc],
      });
    } catch (error) {
      if (error instanceof Jose.errors.JOSEError) {
        return undefined;
      } else {
        throw error;
      }
    }
  }

  async #generateState(): Promise<State> {
    const [nonce, state, code] = await Promise.all([
      SecureRandom.string(32),
      SecureRandom.string(64),
      OAuth.generateCodeVerifier(),
    ]);
    return {
      nonce,
      state,
      code,
      iat: Instant.now(),
    };
  }

  async redirect(origin: string): Promise<{ url: string; state: string }> {
    const state = await this.#generateState();
    const [encodedState, redirect] = await Promise.all([
      this.#encrypt(State.encode(state)),
      this.#client.authorizationCode.getAuthorizeUri({
        redirectUri: new URL(Auth.redirectPath, origin).toString(),
        state: state.state,
        codeVerifier: state.code,
        scope: ["identify", "guilds.members.read"],
      }),
    ]);
    return { state: encodedState, url: redirect };
  }

  async #getDiscordDetails(
    token: OAuth.OAuth2Token,
  ): Promise<Discord.GuildMember | undefined> {
    const url = new URL(
      `users/@me/guilds/${this.#config.discord.guild}/member`,
      Auth.discordBase,
    );
    const result = await fetch(url, {
      headers: new Headers({
        Authorization: `Bearer ${token.accessToken}`,
      }),
    });
    if (result.status === StatusCodes.NOT_FOUND) {
      return undefined;
    } else {
      return Validation.maybeBody(Discord.GuildMember, await result.json());
    }
  }

  async login(
    server: Server.State,
    origin: string,
    stateCookie: string,
    receivedState: string,
    receivedCode: string,
  ): Promise<{
    user: [Users.Slug, Users.User];
    notifications: Notifications.Notification[];
    session: string;
    expires: Joda.ZonedDateTime;
  }> {
    const result = await this.#decrypt(stateCookie);
    const decoded = Validation.maybeBody(State, result?.payload);
    if (decoded !== undefined && decoded.state === receivedState) {
      const token = await this.#client.authorizationCode.getToken({
        code: receivedCode,
        redirectUri: new URL(Auth.redirectPath, origin).toString(),
        codeVerifier: decoded.code,
      });
      const discord = await this.#getDiscordDetails(token);
      if (discord === undefined) {
        throw new WebError(StatusCodes.FORBIDDEN, "Must be a member of JADS.");
      }
      if (discord.pending) {
        throw new WebError(
          StatusCodes.FORBIDDEN,
          "Must be a non-pending member of JADS.",
        );
      }
      const refreshToken = token.refreshToken;
      if (refreshToken === null) {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "Discord did not provide a refresh token.",
        );
      }
      const expiresAt = token.expiresAt;
      if (expiresAt === null) {
        throw new WebError(
          StatusCodes.SERVICE_UNAVAILABLE,
          "Discord did not provide an expiry time.",
        );
      }
      const discriminator =
        discord.user.discriminator !== "0"
          ? (discord.user.discriminator ?? null)
          : null;
      const avatarUrl = avatar(
        discord.user.id,
        discriminator,
        discord.user.avatar ?? null,
        this.#config.discord.guild,
        discord.avatar ?? null,
      );
      const [login, nonce] = await Promise.all([
        server.store.login(
          discord.user.id,
          discord.user.username,
          discord.nick ?? discord.user.global_name ?? null,
          discriminator,
          avatarUrl,
          token.accessToken,
          refreshToken,
          Joda.Instant.ofEpochMilli(expiresAt),
        ),
        SecureRandom.string(32),
      ]);
      const user = Users.fromInternal(login.user);
      const notifications = login.notifications.map(Notifications.fromInternal);
      const sessionToken = SecretToken.fromUri(login.user.session);
      if (sessionToken === undefined) {
        throw new Error("Invalid secret session token generated.");
      }
      const sessionCookie: SessionCookie = {
        nonce,
        user: user[0],
        session: sessionToken,
        iat: Instant.now(),
      };
      return {
        user,
        notifications,
        session: await this.#encrypt(SessionCookie.encode(sessionCookie)),
        expires: login.user.started.plus(this.#config.sessions.lifetime),
      };
    } else {
      throw new Error("Invalid state received.");
    }
  }

  async refresh(
    logger: Logging.Logger,
    token: string,
  ): Promise<DiscordToken | undefined> {
    try {
      // This requires the full token even though it doesn't use it, so we just fake it.
      const result = await this.#client.refreshToken({
        accessToken: "",
        refreshToken: token,
        expiresAt: null,
      });
      if (result.expiresAt === null) {
        logger.warn("Got no expiration time from Discord.");
        return undefined;
      }
      if (result.refreshToken === null) {
        logger.warn("Got no refresh token from Discord.");
        return undefined;
      }
      return {
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        expiresAt: Joda.Instant.ofEpochMilli(result.expiresAt),
      };
    } catch (error: unknown) {
      // This is expected, but we'll log it debug.
      logger.debug({ err: error }, "Expected error while refreshing token.");
      return undefined;
    }
  }

  async #decodeExternal(
    token: string,
  ): Promise<Jose.JWTVerifyResult | undefined> {
    if (this.#externalServices !== undefined) {
      const { config, recognised } = this.#externalServices;
      try {
        // Unvalidated claims at this point!
        const { iss } = Jose.decodeJwt(token);
        const publicKey = iss !== undefined ? recognised.get(iss) : undefined;
        if (publicKey !== undefined) {
          return await Jose.jwtVerify(token, publicKey, {
            algorithms: ["EdDSA"],
            maxTokenAge: config.tokenLifetime.seconds(),
            audience: config.identity,
          });
        } else {
          return undefined;
        }
      } catch (error) {
        if (error instanceof Jose.errors.JOSEError) {
          return undefined;
        } else {
          throw error;
        }
      }
    } else {
      return undefined;
    }
  }

  async getCredential(context: Server.Context): Promise<Credential> {
    const cookie = context.cookies.get(Auth.sessionCookieName, {
      signed: true,
    });
    if (cookie !== undefined) {
      const decrypted = await this.#decrypt(cookie);
      if (decrypted !== undefined) {
        const result = SessionCookie.decode(decrypted.payload);
        if (Either.isRight(result)) {
          const { user, session, iat } = result.right;
          return iat.plus(this.#config.sessions.lifetime).isAfter(Instant.now())
            ? {
                credential: "user-session",
                user,
                session,
              }
            : {
                credential: "unauthorized",
                reason: "expired-session",
              };
        }
      }
      return {
        credential: "unauthorized",
        reason: "invalid-session",
      };
    } else {
      const authorization = context.request.headers["Authorization"];
      if (typeof authorization === "string") {
        const [scheme, token] = authorization.split(" ");
        if (scheme === "Bearer" && token !== undefined) {
          const decoded = await this.#decodeExternal(token);
          if (decoded !== undefined) {
            const result = ExternalServiceToken.decode(decoded.payload);
            if (Either.isRight(result)) {
              return {
                credential: "external-service",
                service: result.right.iss,
                actingAs: result.right.sub,
              };
            } else {
              throw new WebError(StatusCodes.BAD_REQUEST, "Malformed token.");
            }
          } else {
            throw new WebError(StatusCodes.FORBIDDEN, "Token not accepted.");
          }
        } else {
          throw new WebError(
            StatusCodes.BAD_REQUEST,
            "Must provide a bearer token.",
          );
        }
      } else {
        return {
          credential: "unauthorized",
        };
      }
    }
  }

  requireUserSession(
    credential: Credentials.Identifying,
  ): Credentials.UserSession {
    if (credential.credential === "user-session") {
      return credential;
    } else {
      throw new WebError(
        StatusCodes.FORBIDDEN,
        "Only user sessions are allowed to use this API.",
      );
    }
  }

  unauthorizedMessage({ reason }: Credentials.Unauthorized): string {
    switch (reason) {
      case "invalid-session":
        return "Your session was invalid, please try logging in again.";
      case "expired-session":
        return "Your session has expired, please try logging in again.";
      case undefined:
        return "You need to log in to do this.";
      default:
        return Expect.exhaustive("credential reason", (reason) =>
          JSON.stringify(reason),
        )(reason);
    }
  }

  throwUnauthorized(credential: Credentials.Unauthorized): never {
    throw new WebError(
      StatusCodes.UNAUTHORIZED,
      this.unauthorizedMessage(credential),
    );
  }

  async requireIdentifyingCredential(
    context: Server.Context,
  ): Promise<Credentials.Identifying> {
    const credential = await this.getCredential(context);
    return credential.credential !== "unauthorized"
      ? credential
      : this.throwUnauthorized(credential);
  }

  async logout(
    server: Server.State,
    userSlug: Users.Slug,
    session: SecretToken,
  ): Promise<void> {
    await server.store.logout(userSlug, session);
  }
}
