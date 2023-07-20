import { z } from "zod";

export const BetComplete = z
  .object({
    game_name: z.string(),
    bet_name: z.string(),
    spoiler: z.boolean(),
    winning_stakes_count: z.number().int().nonnegative(),
    total_staked_amount: z.number().int().nonnegative(),
    top_winning_discord_ids: z.array(z.string()),
    biggest_payout_amount: z.number().int().nonnegative(),
  })
  .strict();
export type BetComplete = z.infer<typeof BetComplete>;

export const NewStake = z
  .object({
    game_name: z.string(),
    bet_name: z.string(),
    option_name: z.string(),
    spoiler: z.boolean(),
    user_discord_id: z.string(),
  })
  .strict();
export type NewStake = z.infer<typeof NewStake>;

export * as ExternalNotifier from "./external-notifier.js";
