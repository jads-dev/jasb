import { z } from "zod";

import { Bets, Users } from "../internal.js";
import { Types } from "./types.js";

export const Progress = z.enum(["Future", "Current", "Finished"]);
export type Progress = z.infer<typeof Progress>;

export const Game = z
  .object({
    slug: Types.gameSlug,
    name: z.string(),
    cover: z.string(),
    started: Types.localDate.nullable(),
    finished: Types.localDate.nullable(),
    progress: Progress,
    order: Types.int.nullable(),
    managers: z.array(Users.Summary),
    version: Types.nonNegativeInt,
    created: Types.zonedDateTime,
    modified: Types.zonedDateTime,
  })
  .strict();
export type Game = z.infer<typeof Game>;

export const BetStats = z
  .object({
    bets: Types.nonNegativeInt,
    staked: Types.nonNegativeInt,
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
