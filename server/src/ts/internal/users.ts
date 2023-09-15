import { z } from "zod";

import { Types } from "./types.js";

const UserBase = z
  .object({
    slug: Types.userSlug,
    name: z.string(),
    discriminator: z.string().nullable(),
    created: Types.zonedDateTime,
    balance: Types.int,
    avatar_url: z.string().url(),
    staked: Types.nonNegativeInt,
    net_worth: Types.int,
  })
  .strict();

export const User = z
  .object({
    manage_games: z.boolean(),
    manage_permissions: z.boolean(),
    manage_gacha: z.boolean(),
    manage_bets: z.array(Types.gameSlug),
  })
  .strict()
  .merge(UserBase);
export type User = z.infer<typeof User>;

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
 * The permissions about a specific game a user with the right permissions can
 * edit about another user.
 */
export const SpecificPermissions = z
  .object({
    game_slug: Types.gameSlug,
    game_name: z.string(),
    manage_bets: z.boolean(),
  })
  .strict();
export type SpecificPermissions = z.infer<typeof SpecificPermissions>;

/**
 * The general and specific permissions a user with the right permissions can
 * edit about another user.
 */
export const EditablePermissions = z
  .object({
    manage_games: z.boolean(),
    manage_permissions: z.boolean(),
    manage_gacha: z.boolean(),
    manage_bets: z.boolean(),
    game_specific: z.array(SpecificPermissions),
  })
  .strict();
export type EditablePermissions = z.infer<typeof EditablePermissions>;

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
 * The detail for forging a card.
 */
export const ForgeDetail = z.object({
  name: z.string(),
  image: z.string(),
});
export type ForgeDetail = z.infer<typeof ForgeDetail>;

export * as Users from "./users.js";
