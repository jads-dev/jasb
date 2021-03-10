import { Option } from "./options";

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

export type Progress = Voting | Locked | Complete | Cancelled;

export interface Bet {
  name: string;
  description: string;
  spoiler: boolean;

  progress: Progress;

  options: { id: string; option: Option }[];
}

export * as Bets from "./bets";
