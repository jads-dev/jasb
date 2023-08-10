import { z } from "zod";

import { Types } from "./types.js";
import { Users } from "./users.js";

export const SlugAndName = <T extends z.ZodTypeAny>(slug: T) =>
  z
    .object({
      slug: slug,
      name: z.string(),
    })
    .strict();

export const NewBet = z
  .object({
    type: z.literal("NewBet"),
    game: SlugAndName(Types.gameSlug),
    bet: SlugAndName(Types.betSlug),
    spoiler: z.boolean(),
  })
  .strict();
export type NewBet = z.infer<typeof NewBet>;

export const BetComplete = z
  .object({
    type: z.literal("BetComplete"),
    game: SlugAndName(Types.gameSlug),
    bet: SlugAndName(Types.betSlug),
    spoiler: z.boolean(),
    winners: z.array(SlugAndName(Types.optionSlug)),
    highlighted: z
      .object({
        winners: z.array(Users.Summary),
        amount: Types.nonNegativeInt,
      })
      .strict(),
    totalReturn: Types.nonNegativeInt,
    winningStakes: Types.nonNegativeInt,
  })
  .strict();
export type BetComplete = z.infer<typeof BetComplete>;

export const NotableStake = z
  .object({
    type: z.literal("NotableStake"),
    game: SlugAndName(Types.gameSlug),
    bet: SlugAndName(Types.betSlug),
    spoiler: z.boolean(),
    option: SlugAndName(Types.optionSlug),
    user: Users.Summary,
    message: z.string(),
    stake: Types.positiveInt,
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
    time: Types.zonedDateTime,
  })
  .strict();
export type Item = z.infer<typeof Item>;

export * as Feed from "./feed.js";
