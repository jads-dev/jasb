import { z } from "zod";

import { Options } from "./options.js";
import { zonedDateTime } from "./types.js";

export const Progress = z.enum(["Voting", "Locked", "Complete", "Cancelled"]);
export type Progress = z.infer<typeof Progress>;

export const LockMoment = z
  .object({
    slug: z.string(),
    name: z.string(),
    order: z.number().int(),
    bet_count: z.number().int(),
    version: z.number().int().nonnegative(),
    created: zonedDateTime,
    modified: zonedDateTime,
  })
  .strict();
export type LockMoment = z.infer<typeof LockMoment>;

export const Bet = z
  .object({
    slug: z.string(),
    name: z.string(),
    description: z.string(),
    spoiler: z.boolean(),
    lock_moment_slug: z.string(),
    lock_moment_name: z.string(),
    progress: Progress,
    cancelled_reason: z.string().nullable(),
    resolved: zonedDateTime.nullable(),
  })
  .strict();
export type Bet = z.infer<typeof Bet>;

export const GameSummary = z
  .object({
    game_name: z.string(),
  })
  .strict();
export type GameSummary = z.infer<typeof GameSummary>;

export const WithOptions = Bet.merge(
  z
    .object({
      options: z.array(Options.Option),
    })
    .strict(),
);
export type WithOptions = z.infer<typeof WithOptions>;

export const EditableBet = Bet.merge(
  z
    .object({
      author_slug: z.string(),
      author_name: z.string(),
      author_discriminator: z.string().nullable(),
      author_avatar_url: z.string(),
      options: z.array(Options.EditableOption),
      created: zonedDateTime,
      version: z.number().int().nonnegative(),
      modified: zonedDateTime,
    })
    .strict(),
);
export type EditableBet = z.infer<typeof EditableBet>;

export const LockStatus = z
  .object({
    bet_slug: z.string(),
    bet_name: z.string(),
    bet_version: z.number().int().nonnegative(),
    lock_moment_slug: z.string(),
    locked: z.boolean(),
  })
  .strict();
export type LockStatus = z.infer<typeof LockStatus>;

export * as Bets from "./bets.js";
