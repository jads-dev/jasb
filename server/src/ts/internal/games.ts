import { z } from "zod";

import { Bets, Users } from "../internal.js";
import { localDate, zonedDateTime } from "./types.js";

export const Progress = z.enum(["Future", "Current", "Finished"]);
export type Progress = z.infer<typeof Progress>;

export const Game = z
  .object({
    slug: z.string(),
    name: z.string(),
    cover: z.string(),
    started: localDate.nullable(),
    finished: localDate.nullable(),
    progress: Progress,
    order: z.number().int().nullable(),
    managers: z.array(Users.Summary),
    version: z.number().int().nonnegative(),
    created: zonedDateTime,
    modified: zonedDateTime,
  })
  .strict();
export type Game = z.infer<typeof Game>;

export const BetStats = z
  .object({
    bets: z.number().int().nonnegative(),
    staked: z.number().int().nonnegative(),
  })
  .strict();
export type BetStats = z.infer<typeof BetStats>;

export const WithBets = z
  .object({
    bets: z.array(Bets.Bet.merge(Bets.WithOptions)),
  })
  .strict();
export type WithBets = z.infer<typeof WithBets>;

export const Name = z
  .object({
    name: z.string(),
  })
  .strict();
export type Name = z.infer<typeof Name>;

export * as Games from "./games.js";
