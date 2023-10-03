import * as Schema from "io-ts";

import { Validation } from "../util/validation.js";

/**
 * We are more permissive (e.g: `object` over `strictObject`) as Discord's API
 * might change under our feet.
 */

export const User = Schema.readonly(
  Schema.intersection([
    Schema.type({
      id: Schema.string,
      username: Schema.string,
    }),
    Schema.partial({
      discriminator: Schema.union([Schema.string, Schema.null]),
      global_name: Schema.union([Schema.string, Schema.null]),
      avatar: Schema.union([Schema.string, Schema.null]),
      bot: Schema.boolean,
      system: Schema.boolean,
      banner: Schema.union([Schema.string, Schema.null]),
      accent_color: Schema.union([Schema.number, Schema.null]),
      locale: Schema.string,
      verified: Schema.boolean,
      avatar_decoration: Schema.union([Schema.string, Schema.null]),
    }),
  ]),
);
export type User = Schema.TypeOf<typeof User>;

export const GuildMember = Schema.readonly(
  Schema.intersection([
    Schema.type({
      user: User,
    }),
    Schema.partial({
      nick: Schema.union([Schema.string, Schema.null]),
      avatar: Schema.union([Schema.string, Schema.null]),
      joined_at: Validation.DateTime,
      pending: Schema.boolean,
      communication_disabled_until: Schema.union([
        Validation.DateTime,
        Schema.null,
      ]),
    }),
  ]),
);
export type GuildMember = Schema.TypeOf<typeof GuildMember>;

const mod = (n: number, d: number): number => ((n % d) + d) % d;

export const defaultAvatar = (
  id: string,
  discriminator: string | null | undefined,
): number =>
  discriminator === null || discriminator === undefined || discriminator === "0"
    ? mod(parseInt(id) >> 22, 6)
    : mod(parseInt(discriminator), 5);

export * as Discord from "./discord.js";
