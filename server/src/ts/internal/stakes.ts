import { z } from "zod";

import { Types } from "./types.js";
import { Users } from "./users.js";

export const Stake = z
  .object({
    user: Users.Summary,
    made_at: Types.zonedDateTime,
    amount: Types.positiveInt,
    message: z.string().nullable(),
  })
  .strict();
export type Stake = z.infer<typeof Stake>;

export const NewBalance = z
  .object({
    new_balance: Types.int,
  })
  .strict();
export type NewBalance = z.infer<typeof NewBalance>;

export * as Stakes from "./stakes.js";
