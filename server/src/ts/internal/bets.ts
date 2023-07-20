import { z } from "zod";

import { Options } from "./options.js";
import { zonedDateTime } from "./types.js";

export const Progress = z.enum(["Voting", "Locked", "Complete", "Cancelled"]);
export type Progress = z.infer<typeof Progress>;

export const Bet = z
  .object({
    game: z.string(),
    id: z.string(),
    name: z.string(),
    description: z.string(),
    spoiler: z.boolean(),

    locks_when: z.string(),
    progress: Progress,
    cancelled_reason: z.string().nullable(),
    resolved: zonedDateTime.nullable(),

    by: z.string(),
    created: zonedDateTime,
    version: z.number().int().nonnegative(),
    modified: zonedDateTime,
  })
  .strict();
export type Bet = z.infer<typeof Bet>;

export const GameSummary = z
  .object({
    game_name: z.string(),
  })
  .strict();
export type GameSummary = z.infer<typeof GameSummary>;

export const WithOptions = z
  .object({
    options: z.array(Options.AndStakes),
  })
  .strict();
export type WithOptions = z.infer<typeof WithOptions>;

export const Author = z
  .object({
    author_name: z.string(),
    author_discriminator: z.string().nullable(),
    author_avatar: z.string().nullable(),
  })
  .strict();
export type Author = z.infer<typeof Author>;

export const LockStatus = z
  .object({
    id: z.string(),
    name: z.string(),
    locks_when: z.string(),
    locked: z.boolean(),
    version: z.number().int().nonnegative(),
  })
  .strict();
export type LockStatus = z.infer<typeof LockStatus>;

export * as Bets from "./bets.js";
