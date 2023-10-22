import { z } from "zod";

import { Types } from "./types.js";

const UserBase = z.object({
  slug: Types.userSlug,
  discord_id: z.string(),
  name: z.string(),
  discriminator: z.string().nullable(),
  created: Types.zonedDateTime,
  balance: Types.int,
  avatar_url: z.string(),
  staked: Types.nonNegativeInt,
  net_worth: Types.int,
});

const PermissionsBase = z.object({
  manage_games: z.boolean(),
  manage_permissions: z.boolean(),
  manage_gacha: z.boolean(),
  manage_bets: z.boolean(),
  manage_bets_games: z.array(
    z.strictObject({ slug: Types.gameSlug, name: z.string() }),
  ),
});

export const User = UserBase.merge(PermissionsBase).strict();
export type User = z.infer<typeof User>;

export const Permissions = PermissionsBase.strict();
export type Permissions = z.infer<typeof Permissions>;

export const Leaderboard = z
  .object({
    rank: Types.nonNegativeInt,
  })
  .strict()
  .merge(UserBase);
export type Leaderboard = z.infer<typeof Leaderboard>;

export const LoginDetail = z
  .object({
    user: Types.nonNegativeInt,
    session: z.string(),
    started: Types.zonedDateTime,
  })
  .strict();
export type LoginDetail = z.infer<typeof LoginDetail>;

export const Summary = User.pick({
  slug: true,
  name: true,
  discriminator: true,
  avatar_url: true,
  discord_id: true,
});
export type Summary = z.infer<typeof Summary>;

export const BankruptcyStats = z
  .object({
    amount_lost: Types.int,
    stakes_lost: Types.int,
    locked_amount_lost: Types.int,
    locked_stakes_lost: Types.int,
    balance_after: Types.int,
  })
  .strict();
export type BankruptcyStats = z.infer<typeof BankruptcyStats>;

/**
 * The discord access token for a user.
 */
export const DiscordAccessToken = z
  .object({
    access_token: z.string(),
  })
  .strict();
export type DiscordAccessToken = z.infer<typeof DiscordAccessToken>;

/**
 * The discord refresh token for a user.
 */
export const DiscordRefreshToken = z
  .object({
    id: Types.int,
    refresh_token: z.string(),
  })
  .strict();
export type DiscordRefreshToken = z.infer<typeof DiscordRefreshToken>;

/**
 * The detail for forging a card.
 */
export const ForgeDetail = z.object({
  name: z.string(),
  image: z.string(),
});
export type ForgeDetail = z.infer<typeof ForgeDetail>;

export * as Users from "./users.js";
