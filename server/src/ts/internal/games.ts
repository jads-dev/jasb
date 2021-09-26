import * as Joda from "@js-joda/core";

import { Users, Bets } from "../internal";

export type Progress = "Future" | "Current" | "Finished";

export interface Game {
  id: string;
  name: string;
  cover: string;
  igdb_id: string;

  progress: Progress;
  started: Joda.LocalDate | null;
  finished: Joda.LocalDate | null;

  added: Joda.ZonedDateTime;
  version: number;
  modified: Joda.ZonedDateTime;
}

export interface BetStats {
  bets: number;
}

export interface EmbeddedBets {
  bets: (Bets.Bet & Bets.Options)[];
}

export interface StakeStats {
  staked: number;
}

export interface Mods {
  mods: Users.Summary[];
}

export * as Games from "./games";
