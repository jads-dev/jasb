import * as Joda from "@js-joda/core";

import { Users } from "./users.js";

export interface IdAndName {
  id: string;
  name: string;
}

export interface NewBet {
  type: "NewBet";
  game: IdAndName;
  bet: IdAndName;
  spoiler: boolean;
}

export interface BetComplete {
  type: "BetComplete";
  game: IdAndName;
  bet: IdAndName;
  spoiler: boolean;
  winners: IdAndName[];
  highlighted: {
    winners: Users.Summary[];
    amount: number;
  };
  totalReturn: number;
  winningStakes: number;
}

export interface NotableStake {
  type: "NotableStake";
  game: IdAndName;
  bet: IdAndName;
  spoiler: boolean;
  option: IdAndName;
  user: Users.Summary;
  message: string;
  stake: number;
}

export type Event = NewBet | BetComplete | NotableStake;

export interface Item {
  item: Event;
  time: Joda.ZonedDateTime;
}

export * as Feed from "./feed.js";
