import * as Joda from "@js-joda/core";

import { Options } from "./options.js";

export type Progress = "Voting" | "Locked" | "Complete" | "Cancelled";

export interface Bet {
  game: string;
  id: string;
  name: string;
  description: string;
  spoiler: boolean;

  locks_when: string;
  progress: Progress;
  cancelled_reason: string;
  resolved: Joda.ZonedDateTime | null;

  by: string;
  created: Joda.ZonedDateTime;
  version: number;
  modified: Joda.ZonedDateTime;
}

export interface GameSummary {
  game_name: string;
}

export interface Options {
  options: Options.AndStakes[];
}

export interface Author {
  author_name: string;
  author_discriminator: string;
  author_avatar: string | null;
}

export interface LockStatus {
  id: string;
  name: string;
  locks_when: string;
  locked: boolean;
  version: number;
}

export * as Bets from "./bets.js";
