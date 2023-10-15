import { z } from "zod";

import { Users } from "../internal/users.js";
import { SlugAndName } from "./feed.js";
import { Types } from "./types.js";

export const BetComplete = z
  .object({
    game_name: z.string(),
    bet_name: z.string(),
    spoiler: z.boolean(),
    winners: z.array(SlugAndName(Types.optionSlug)),
    winning_stakes_count: Types.nonNegativeInt,
    total_staked_amount: Types.nonNegativeInt,
    top_winning_users: z.array(Users.Summary),
    biggest_payout_amount: Types.nonNegativeInt,
  })
  .strict();
export type BetComplete = z.infer<typeof BetComplete>;

export const NewStake = z
  .object({
    game_name: z.string(),
    bet_name: z.string(),
    option_name: z.string(),
    spoiler: z.boolean(),
    user_summary: Users.Summary,
  })
  .strict();
export type NewStake = z.infer<typeof NewStake>;

export * as ExternalNotifier from "./external-notifier.js";
