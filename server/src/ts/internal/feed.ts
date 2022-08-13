import { z } from "zod";

import { zonedDateTime } from "./types.js";
import { Users } from "./users.js";

export const IdAndName = z
  .object({
    id: z.string(),
    name: z.string(),
  })
  .strict();
export type IdAndName = z.infer<typeof IdAndName>;

export const NewBet = z
  .object({
    type: z.literal("NewBet"),
    game: IdAndName,
    bet: IdAndName,
    spoiler: z.boolean(),
  })
  .strict();
export type NewBet = z.infer<typeof NewBet>;

export const BetComplete = z
  .object({
    type: z.literal("BetComplete"),
    game: IdAndName,
    bet: IdAndName,
    spoiler: z.boolean(),
    winners: z.array(IdAndName),
    highlighted: z
      .object({
        winners: z.array(Users.User),
        amount: z.number().int().positive(),
      })
      .strict(),
    totalReturn: z.number().int().positive(),
    winningStakes: z.number().int().positive(),
  })
  .strict();
export type BetComplete = z.infer<typeof BetComplete>;

export const NotableStake = z
  .object({
    type: z.literal("NotableStake"),
    game: IdAndName,
    bet: IdAndName,
    spoiler: z.boolean(),
    option: IdAndName,
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
