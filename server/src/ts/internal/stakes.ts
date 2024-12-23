import { z } from "zod";

import { Types } from "./types.js";
import { Users } from "./users.js";
import { Gacha } from "./gacha.js";

export const Stake = z
  .object({
    user: Users.Summary,
    made_at: Types.zonedDateTime,
    amount: Types.positiveInt,
    message: z.string().nullable(),
    payout: z
      .object({
        amount: Types.positiveInt.nullable(),
        gacha: Gacha.Balances.Value.nullable(),
      })
      .strict()
      .nullable(),
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
