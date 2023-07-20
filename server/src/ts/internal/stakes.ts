import { z } from "zod";

import { zonedDateTime } from "./types.js";
import { Users } from "./users.js";

export const Stake = z
  .object({
    user: Users.Summary,
    made_at: zonedDateTime,
    amount: z.number().int().positive(),
    message: z.string().nullable(),
  })
  .strict();
export type Stake = z.infer<typeof Stake>;

export const NewBalance = z
  .object({
    new_balance: z.number().int(),
  })
  .strict();
export type NewBalance = z.infer<typeof NewBalance>;

export * as Stakes from "./stakes.js";
