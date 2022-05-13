import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Expect } from "../../util/expect.js";
import { Option, Options } from "./options.js";

interface BetIdBrand {
  readonly BetId: unique symbol;
}

export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, BetIdBrand> => true,
  "BetId",
);
export type Id = Schema.TypeOf<typeof Id>;

export interface Voting {
  state: "Voting";
  locksWhen: string;
}

export interface Locked {
  state: "Locked";
}

export interface Complete {
  state: "Complete";
  winners: Options.Id[];
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
  author: string;

  progress: Progress;

  options: { id: Options.Id; option: Option }[];
}

export interface WithId {
  id: Id;
  bet: Bet;
}

export interface LockStatus {
  id: Id;
  name: string;
  locksWhen: string;
  locked: boolean;
  version: number;
}

export const unknownProgress = Expect.exhaustive(
  "bet progress",
  (i: Internal.Games.Progress) => i,
);

const progressFromInternal = (
  internal: Internal.Bet & Internal.Bets.Options,
): Progress => {
  switch (internal.progress) {
    case "Voting":
      return { state: "Voting", locksWhen: internal.locks_when };

    case "Locked":
      return { state: "Locked" };

    case "Complete": {
      const winners = internal.options
        .filter((option) => option.option.won)
        .map((option) => option.option.id);
      return { state: "Complete", winners: winners as Options.Id[] };
    }

    case "Cancelled":
      return { state: "Cancelled", reason: internal.cancelled_reason };

    default:
      return unknownProgress(internal.progress);
  }
};

export const fromInternal = (
  internal: Internal.Bet & Internal.Bets.Options,
): WithId => ({
  id: internal.id as Id,
  bet: {
    name: internal.name,
    description: internal.description,
    spoiler: internal.spoiler,
    author: internal.by,

    progress: progressFromInternal(internal),

    options: internal.options.map((internalOption) => {
      const [id, option] = Options.fromInternal(internalOption);
      return { id, option };
    }),
  },
});

export const lockStatusFromInternal = (
  internal: Internal.Bets.LockStatus,
): LockStatus => ({
  id: internal.id as Id,
  name: internal.name,
  locksWhen: internal.locks_when,
  locked: internal.locked,
  version: internal.version,
});
