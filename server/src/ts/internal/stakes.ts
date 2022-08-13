import { z } from "zod";

import { zonedDateTime } from "./types.js";
import { Users } from "./users.js";

export const Stake = z
  .object({
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    owner: z.string(),

    made_at: zonedDateTime,

    amount: z.number().int().positive(),
    message: z.string().nullable(),

    payout: z.number().int().nonnegative().nullable(),
  })
  .strict();
export type Stake = z.infer<typeof Stake>;

export const WithUser = z
  .object({
    stake: Stake,
    user: Users.User,
  })
  .strict();
export type WithUser = z.infer<typeof WithUser>;

export const NewBalance = z
  .object({
    new_balance: z.number().int(),
  })
  .strict();
export type NewBalance = z.infer<typeof NewBalance>;

export * as Stakes from "./stakes.js";
