import { Timestamp } from "@google-cloud/firestore";

import { Option } from "../v3";

export interface Suggestion {
  state: "Suggestion";
  by: string;
}

export interface Voting {
  state: "Voting";
  locksWhen: string;
}

export interface Locked {
  state: "Locked";
}

export interface Complete {
  state: "Complete";
  winner: string;
}

export interface Cancelled {
  state: "Cancelled";
  reason: string;
}

export type Progress = Suggestion | Voting | Locked | Complete | Cancelled;

export interface Bet {
  name: string;
  description: string;
  spoiler: boolean;
  created: Timestamp;
  updated: Timestamp;

  progress: Progress;

  options: { id: string; option: Option }[];
}

export * as Bets from "./bets";
