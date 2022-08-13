import { z } from "zod";

import { Bets, Users } from "../internal.js";
import { localDate, zonedDateTime } from "./types.js";

export const Progress = z.enum(["Future", "Current", "Finished"]);
export type Progress = z.infer<typeof Progress>;

export const Game = z
  .object({
    id: z.string(),
    name: z.string(),
    cover: z.string(),
    igdb_id: z.string(),

    progress: Progress,
    started: localDate.nullable(),
    finished: localDate.nullable(),
    order: z.number().int().nullable(),

    added: zonedDateTime,
    version: z.number().int().nonnegative(),
    modified: zonedDateTime,
  })
  .strict();
export type Game = z.infer<typeof Game>;

export const BetStats = z
  .object({
    bets: z.number().int().nonnegative(),
  })
  .strict();
export type BetStats = z.infer<typeof BetStats>;

export const EmbeddedBets = z
  .object({
    bets: z.array(Bets.Bet.merge(Bets.WithOptions)),
  })
  .strict();
export type EmbeddedBets = z.infer<typeof EmbeddedBets>;

export const StakeStats = z
  .object({
    staked: z.number().int().nonnegative(),
  })
  .strict();
export type StakeStats = z.infer<typeof StakeStats>;

export const Mods = z
  .object({
    mods: z.array(Users.User),
  })
  .strict();
export type Mods = z.infer<typeof Mods>;

export const Name = z
  .object({
    name: z.string(),
  })
  .strict();
export type Name = z.infer<typeof Name>;

export * as Games from "./games.js";
