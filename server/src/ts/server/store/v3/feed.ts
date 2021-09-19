import { Timestamp } from "@google-cloud/firestore";

export interface IdAndName {
  id: string;
  name: string;
}

export interface UserInfo {
  id: string;
  name: string;
  discriminator: string;
  avatar?: string;
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
  winner: IdAndName | IdAndName[];
  highlighted: {
    winners: UserInfo[];
    amount: number;
  };
  totalReturn: number;
  winners: number;
}

export interface NotableStake {
  type: "NotableStake";
  game: IdAndName;
  bet: IdAndName;
  spoiler: boolean;
  option: IdAndName;
  user: UserInfo;
  message: string;
  stake: number;
}

export type Event = NewBet | BetComplete | NotableStake;

export interface Item {
  event: Event;
  at: Timestamp;
}

export * as Feed from "./feed";
