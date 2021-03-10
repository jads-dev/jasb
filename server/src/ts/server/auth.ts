import * as Crypto from "crypto";
import { default as Discord } from "discord-oauth2";
import { StatusCodes } from "http-status-codes";
import parseJwk, { KeyLike } from "jose/jwk/parse";
import SignJWT from "jose/jwt/sign";
import jwtVerify from "jose/jwt/verify";
import * as Util from "util";

import { Games } from "../public/games";
import { Users } from "../public/users";
import { Config } from "./config";
import { WebError } from "./errors";
import { Store } from "./store";

const randomBytes = Util.promisify(Crypto.randomBytes);

export interface Claims {
  uid: Users.Id;
  admin?: boolean;
  mod?: Games.Id[];
}

export class Auth {
  config: Config.Auth;
  store: Store;
  oauth: Discord;
  secret: KeyLike;

  private constructor(config: Config.Auth, store: Store, secret: KeyLike) {
    this.config = config;
    this.store = store;
    this.oauth = new Discord({
      clientId: config.discord.clientId,
      clientSecret: config.discord.clientSecret,
    });
    this.secret = secret;
  }

  static async init(config: Config.Auth, store: Store): Promise<Auth> {
    const secret = await parseJwk(config.privateKey);
    return new Auth(config, store, secret);
  }

  async redirect(origin: string): Promise<{ url: string; state: string }> {
    const rawState = await randomBytes(16);
    const state = rawState.toString("hex");
    return {
      url: await this.oauth.generateAuthUrl({
        scope: this.config.discord.scopes,
        redirectUri: new URL("/auth", origin).toString(),
        state,
        prompt: "consent",
      }),
      state,
    };
  }

  async login(
    origin: string,
    code: string
  ): Promise<{ user: Users.WithId; token: string }> {
    const discordToken = await this.oauth.tokenRequest({
      scope: this.config.discord.scopes,
      redirectUri: new URL("/auth", origin).toString(),
      grantType: "authorization_code",
      code,
    });

    const discordUser = await this.oauth.getUser(discordToken.access_token);

    const user: Users.WithId = {
      id: discordUser.id,
      user: Users.fromInternal(
        await this.store.getOrCreateUser(discordToken, discordUser)
      ),
    };

    const token = await new SignJWT({
      ...(user.user.admin === true ? { admin: true } : {}),
      ...(user.user.mod !== undefined ? { mod: user.user.mod } : {}),
    })
      .setProtectedHeader({ alg: "ES256" })
      .setIssuedAt()
      .setSubject(discordUser.id)
      .setExpirationTime(`${this.config.tokenLifetime.as("seconds")}s`)
      .sign(this.secret);

    return {
      user,
      token,
    };
  }

  async tryGetClaims(token: string): Promise<Claims | undefined> {
    try {
      const { payload } = await jwtVerify(token, this.secret);
      return {
        uid: payload.sub as Users.Id,
        admin: payload.admin,
        mod: payload.mod,
      };
    } catch (error) {
      return undefined;
    }
  }

  async validate(token: string): Promise<Claims> {
    const claims = await this.tryGetClaims(token);
    if (claims === undefined) {
      throw new WebError(StatusCodes.BAD_REQUEST, "Invalid token.");
    }
    return claims;
  }

  async logout(accessToken: string): Promise<void> {
    const { clientId, clientSecret } = this.config.discord;
    const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString(
      "base64"
    );
    await this.oauth.revokeToken(accessToken, credentials);
  }
}
