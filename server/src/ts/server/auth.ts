import * as Joda from "@js-joda/core";
import { default as DiscordOAuth } from "discord-oauth2";
import { StatusCodes } from "http-status-codes";

import type { Store } from "../data/store.js";
import { Notifications, Users } from "../public.js";
import { Random } from "../util/random.js";
import { SecretToken } from "../util/secret-token.js";
import type { Config } from "./config.js";
import { WebError } from "./errors.js";

type DiscordUser = DiscordOAuth.User & {
  discriminator?: string | undefined;
  global_name?: string | undefined;
};

export class Auth {
  static readonly secure = process.env["NODE_ENV"] !== "development";
  static readonly sessionCookieName = `${
    Auth.secure ? "__Host-" : ""
  }jasb-session`;
  static readonly stateCookieName = `${Auth.secure ? "__Host-" : ""}jasb-state`;

  config: Config.Auth;
  store: Store;
  oauth: DiscordOAuth;

  private constructor(config: Config.Auth, store: Store) {
    this.config = config;
    this.store = store;
    this.oauth = new DiscordOAuth({
      clientId: config.discord.clientId,
      clientSecret: config.discord.clientSecret.value,
    });
  }

  static init(config: Config.Auth, store: Store): Promise<Auth> {
    return Promise.resolve(new Auth(config, store));
  }

  async redirect(origin: string): Promise<{ url: string; state: string }> {
    const state = await Random.secureRandomString(24);
    return {
      url: this.oauth.generateAuthUrl({
        scope: this.config.discord.scopes,
        redirectUri: new URL("/auth", origin).toString(),
        state,
        prompt: "consent",
      }),
      state,
    };
  }

  async #getDiscordDetails(
    origin: string,
    code: string,
  ): Promise<{
    token: DiscordOAuth.TokenRequestResult;
    user: DiscordUser;
    guilds: readonly DiscordOAuth.PartialGuild[];
  }> {
    try {
      const token = await this.oauth.tokenRequest({
        scope: this.config.discord.scopes,
        redirectUri: new URL("/auth", origin).toString(),
        grantType: "authorization_code",
        code,
      });
      const user = (await this.oauth.getUser(
        token.access_token,
      )) as DiscordUser;
      const guilds = await this.oauth.getUserGuilds(token.access_token);
      return { token, user, guilds };
    } catch (error: unknown) {
      if (error instanceof DiscordOAuth.DiscordHTTPError) {
        console.error(
          JSON.stringify(
            { message: error.message, response: error.response },
            undefined,
            2,
          ),
        );
      }
      throw error;
    }
  }

  async login(
    origin: string,
    code: string,
  ): Promise<{
    user: [Users.Slug, Users.User];
    notifications: Notifications.Notification[];
    session: SecretToken;
    expires: Joda.ZonedDateTime;
  }> {
    const discord = await this.#getDiscordDetails(origin, code);

    const jadsId = this.config.discord.guild;
    const memberOfJads = discord.guilds.some((guild) => guild.id === jadsId);
    if (!memberOfJads) {
      throw new WebError(StatusCodes.FORBIDDEN, "Must be a member of JADS.");
    }

    const login = await this.store.login(
      discord.user.id,
      discord.user.username,
      discord.user.global_name ?? null,
      discord.user.discriminator !== "0" ? discord.user.discriminator : null,
      discord.user.avatar ?? null,
      discord.token.access_token,
      discord.token.refresh_token,
      Joda.Duration.of(discord.token.expires_in, Joda.ChronoUnit.SECONDS),
    );
    const user = Users.fromInternal(login.user);
    const notifications = login.notifications.map(Notifications.fromInternal);
    const session = SecretToken.fromUri(login.user.session);
    if (session === undefined) {
      throw new Error("Invalid secret session token generated.");
    }
    return {
      user,
      notifications,
      session,
      expires: login.user.started.plus(this.config.sessionLifetime),
    };
  }

  async logout(userSlug: Users.Slug, session: SecretToken): Promise<void> {
    const accessToken = await this.store.logout(userSlug, session);
    if (accessToken != null) {
      const { clientId, clientSecret } = this.config.discord;
      const credentials = Buffer.from(
        `${clientId}:${clientSecret.value}`,
      ).toString("base64");
      try {
        await this.oauth.revokeToken(accessToken, credentials);
      } catch (e) {
        // Do nothing, if we can't revoke there isn't much we can do about it.
      }
    }
  }
}
