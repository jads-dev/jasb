import { Internal } from "../internal";
import { Expect } from "../util/expect";
import { Option, Options } from "./options";
import { Users } from "./users";

export type Id = string;

export interface Suggestion {
  state: "Suggestion";
  by: Users.Id;
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
  winner: Options.Id;
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

  progress: Progress;

  options: { id: Options.Id; option: Option }[];
}

export const unknownProgress = Expect.exhaustive(
  "bet progress",
  (i: Internal.Games.Progress) => i.state
);

const progressToInternal = (progress: Internal.Bets.Progress): Progress => {
  switch (progress.state) {
    case "Suggestion":
      return { state: "Suggestion", by: progress.by };

    case "Voting":
      return { state: "Voting", locksWhen: progress.locksWhen };

    case "Locked":
      return { state: "Locked" };

    case "Complete":
      return { state: "Complete", winner: progress.winner };

    case "Cancelled":
      return { state: "Cancelled", reason: progress.reason };

    default:
      return unknownProgress(progress);
  }
};

export const toInternal = (bet: Bet): Internal.Bet => ({
  name: bet.name,
  description: bet.description,
  spoiler: bet.spoiler,

  progress: progressToInternal(bet.progress),

  options: bet.options.map(({ id, option }) => ({
    id,
    option: Options.toInternal(option),
  })),
});

const progressFromInternal = (internal: Internal.Bets.Progress): Progress => {
  switch (internal.state) {
    case "Suggestion":
      return { state: "Suggestion", by: internal.by };

    case "Voting":
      return { state: "Voting", locksWhen: internal.locksWhen };

    case "Locked":
      return { state: "Locked" };

    case "Complete":
      return { state: "Complete", winner: internal.winner };

    case "Cancelled":
      return { state: "Cancelled", reason: internal.reason };

    default:
      return unknownProgress(internal);
  }
};

export const fromInternal = (internal: Internal.Bet): Bet => ({
  name: internal.name,
  description: internal.description,
  spoiler: internal.spoiler,

  progress: progressFromInternal(internal.progress),

  options: internal.options.map(({ id, option }) => ({
    id,
    option: Options.fromInternal(option),
  })),
});

export * as Bets from "./bets";
