import { z } from "zod";

import { zonedDateTime } from "./types.js";

export const User = z
  .object({
    id: z.string(),
    name: z.string(),
    discriminator: z.string().length(4),
    avatar: z.string().nullable(),
    avatar_cache: z.string().url().nullable(),

    created: zonedDateTime,
    admin: z.boolean(),

    balance: z.number().int(),
  })
  .strict();
export type User = z.infer<typeof User>;

export const BetStats = z
  .object({
    staked: z.number().int(),
    net_worth: z.number().int(),
  })
  .strict();
export type BetStats = z.infer<typeof BetStats>;

export const Leaderboard = z
  .object({
    rank: z.number().int().nonnegative(),
  })
  .strict();
export type Leaderboard = z.infer<typeof Leaderboard>;

export const Permissions = z
  .object({
    moderator_for: z.array(z.string()),
  })
  .strict();
export type Permissions = z.infer<typeof Permissions>;

export const LoginDetail = z
  .object({
    session: z.string(),
    started: zonedDateTime,
  })
  .strict();
export type LoginDetail = z.infer<typeof LoginDetail>;

export const Summary = User.pick({
  id: true,
  name: true,
  discriminator: true,
  avatar: true,
  avatar_cache: true,
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

export const PerGamePermissions = z
  .object({
    game_id: z.string(),
    game_name: z.string(),
    manage_bets: z.boolean(),
  })
  .strict();
export type PerGamePermissions = z.infer<typeof PerGamePermissions>;

export const AccessToken = z
  .object({
    access_token: z.string(),
  })
  .strict();
export type AccessToken = z.infer<typeof AccessToken>;

export * as Users from "./users.js";
