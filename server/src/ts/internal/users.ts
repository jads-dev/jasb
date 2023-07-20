import { z } from "zod";

import { zonedDateTime } from "./types.js";

const UserBase = z
  .object({
    slug: z.string(),
    name: z.string(),
    discriminator: z.string().nullable(),
    created: zonedDateTime,
    balance: z.number().int(),
    avatar_url: z.string().url(),
    staked: z.number().int(),
    net_worth: z.number().int(),
  })
  .strict();

export const User = z
  .object({
    manage_games: z.boolean(),
    manage_permissions: z.boolean(),
    manage_bets: z.array(z.string()),
  })
  .strict()
  .merge(UserBase);
export type User = z.infer<typeof User>;

export const Avatar = z
  .object({
    id: z.number().int(),
    discord_user: z.string().nullable(),
    hash: z.string().nullable(),
    default_index: z.number().int().nullable(),
    url: z.string().url(),
    cached: z.boolean(),
  })
  .strict();
export type Avatar = z.infer<typeof Avatar>;

export const Leaderboard = z
  .object({
    rank: z.number().int().nonnegative(),
  })
  .strict()
  .merge(UserBase);
export type Leaderboard = z.infer<typeof Leaderboard>;

export const LoginDetail = z
  .object({
    user: z.number().int(),
    session: z.string(),
    started: zonedDateTime,
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
    amount_lost: z.number().int(),
    stakes_lost: z.number().int(),
    locked_amount_lost: z.number().int(),
    locked_stakes_lost: z.number().int(),
    balance_after: z.number().int(),
  })
  .strict();
export type BankruptcyStats = z.infer<typeof BankruptcyStats>;

/**
 * The permissions about a specific game a user with the right permissions can
 * edit about another user.
 */
export const SpecificPermissions = z
  .object({
    game_slug: z.string(),
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

export * as Users from "./users.js";
