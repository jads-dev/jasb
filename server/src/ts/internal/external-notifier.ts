import { z } from "zod";

import { User } from "./users.js";

export const BetComplete = z
  .object({
    game_name: z.string(),
    bet_name: z.string(),
    spoiler: z.boolean(),
    winning_stakes: z.number().int().nonnegative(),
    total_staked: z.number().int().nonnegative(),
    top_winners: z.array(User),
    biggest_payout: z.number().int().nonnegative(),
  })
  .strict();
export type BetComplete = z.infer<typeof BetComplete>;

export const NewStake = z
  .object({
    game_name: z.string(),
    bet_name: z.string(),
    option_name: z.string(),
    spoiler: z.boolean(),
  })
  .strict();
export type NewStake = z.infer<typeof NewStake>;

export * as ExternalNotifier from "./external-notifier.js";
