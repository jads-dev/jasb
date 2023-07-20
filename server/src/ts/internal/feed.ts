import { z } from "zod";

import { zonedDateTime } from "./types.js";
import { Users } from "./users.js";

export const SlugAndName = z
  .object({
    slug: z.string(),
    name: z.string(),
  })
  .strict();
export type SlugAndName = z.infer<typeof SlugAndName>;

export const NewBet = z
  .object({
    type: z.literal("NewBet"),
    game: SlugAndName,
    bet: SlugAndName,
    spoiler: z.boolean(),
  })
  .strict();
export type NewBet = z.infer<typeof NewBet>;

export const BetComplete = z
  .object({
    type: z.literal("BetComplete"),
    game: SlugAndName,
    bet: SlugAndName,
    spoiler: z.boolean(),
    winners: z.array(SlugAndName),
    highlighted: z
      .object({
        winners: z.array(Users.Summary),
        amount: z.number().int().nonnegative(),
      })
      .strict(),
    totalReturn: z.number().int().nonnegative(),
    winningStakes: z.number().int().nonnegative(),
  })
  .strict();
export type BetComplete = z.infer<typeof BetComplete>;

export const NotableStake = z
  .object({
    type: z.literal("NotableStake"),
    game: SlugAndName,
    bet: SlugAndName,
    spoiler: z.boolean(),
    option: SlugAndName,
    user: Users.Summary,
    message: z.string(),
    stake: z.number().int().positive(),
  })
  .strict();
export type NotableStake = z.infer<typeof NotableStake>;

export const Event = z.discriminatedUnion("type", [
  NewBet,
  BetComplete,
  NotableStake,
]);
export type Event = z.infer<typeof Event>;

export const Item = z
  .object({
    item: Event,
    time: zonedDateTime,
  })
  .strict();
export type Item = z.infer<typeof Item>;

export * as Feed from "./feed.js";
