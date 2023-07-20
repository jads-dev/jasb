import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Expect } from "../../util/expect.js";
import { Option, Options } from "./options.js";

/**
 * An ID for a bet from the perspective of the API user, this is the slug
 * internally.
 */
interface BetIdBrand {
  readonly BetId: unique symbol;
}
export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, BetIdBrand> => true,
  "BetId",
);
export type Id = Schema.TypeOf<typeof Id>;

/**
 * The progress details of a bet that is has open voting.
 */
export const Voting = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Voting"),
    lockMoment: Schema.string,
  }),
);
export type Voting = Schema.TypeOf<typeof Voting>;

/**
 * The progress details of a bet that has locked, but not yet resolved.
 */
export const Locked = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Locked"),
  }),
);
export type Locked = Schema.TypeOf<typeof Locked>;

/**
 * The progress details of a bet that has completed and has (a) winner(s).
 */
export const Complete = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Complete"),
    winners: Schema.readonlyArray(Options.Id),
  }),
);
export type Complete = Schema.TypeOf<typeof Complete>;

/**
 * The progress details of a bet that has been cancelled.
 */
export const Cancelled = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Cancelled"),
    reason: Schema.string,
  }),
);
export type Cancelled = Schema.TypeOf<typeof Cancelled>;

/**
 * The progress details of a bet.
 */
export const Progress = Schema.union([Voting, Locked, Complete, Cancelled]);
export type Progress = Schema.TypeOf<typeof Progress>;

/**
 * A game.
 */
export const Bet = Schema.readonly(
  Schema.strict({
    name: Schema.string,
    description: Schema.string,
    spoiler: Schema.boolean,
    progress: Progress,
    options: Schema.readonlyArray(Schema.tuple([Options.Id, Option])),
  }),
);
export type Bet = Schema.TypeOf<typeof Bet>;

export const unknownProgress = Expect.exhaustive(
  "bet progress",
  (i: Internal.Games.Progress) => i,
);

const progressFromInternal = (
  internal: Internal.Bets.WithOptions,
): Progress => {
  switch (internal.progress) {
    case "Voting":
      return { state: "Voting", lockMoment: internal.lock_moment_name };

    case "Locked":
      return { state: "Locked" };

    case "Complete": {
      const winners = internal.options
        .filter((option) => option.won)
        .map((option) => option.slug);
      return {
        state: "Complete",
        winners: winners.map((w) => w as Options.Id),
      };
    }

    case "Cancelled":
      return { state: "Cancelled", reason: internal.cancelled_reason! };

    default:
      return unknownProgress(internal.progress);
  }
};

export const fromInternal = (
  internal: Internal.Bets.WithOptions,
): [Id, Bet] => [
  internal.slug as Id,
  {
    name: internal.name,
    description: internal.description,
    spoiler: internal.spoiler,
    progress: progressFromInternal(internal),
    options: internal.options.map(Options.fromInternal),
  },
];
