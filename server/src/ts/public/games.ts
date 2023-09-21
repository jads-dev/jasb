import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import { Iterables } from "../util/iterables.js";
import { Validation } from "../util/validation.js";
import { Bets } from "./bets.js";
import { LockMoments } from "./editor/lock-moments.js";
import { Users } from "./users/core.js";

/**
 * A slug for a game.
 */
interface GameSlugBrand {
  readonly GameSlug: unique symbol;
}
export const Slug = Validation.Slug("GameSlug")<GameSlugBrand>();
export type Slug = Schema.TypeOf<typeof Slug>;

/**
 * The progress details of a game that is a future game, not yet started.
 */
export const Future = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Future"),
  }),
);
export type Future = Schema.TypeOf<typeof Future>;

/**
 * The progress details of a game that is a current game, started but not yet
 * finished.
 */
export const Current = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Current"),
    start: Validation.Date,
  }),
);
export type Current = Schema.TypeOf<typeof Current>;

/**
 * The progress details of a game that is a finished game, started and finished.
 */
export const Finished = Schema.readonly(
  Schema.strict({
    state: Schema.literal("Finished"),
    start: Validation.Date,
    finish: Validation.Date,
  }),
);
export type Finished = Schema.TypeOf<typeof Finished>;

/**
 * The progress details of a game.
 */
export const Progress = Schema.union([Future, Current, Finished]);
export type Progress = Schema.TypeOf<typeof Progress>;

/**
 * The base details of a game.
 */
export const Game = Schema.intersection([
  Schema.readonly(
    Schema.strict({
      name: Schema.string,
      cover: Schema.string,
      progress: Progress,
      version: Schema.Int,
      created: Validation.DateTime,
      modified: Validation.DateTime,
      managers: Schema.readonlyArray(Schema.tuple([Users.Slug, Users.Summary])),
    }),
  ),
  Schema.partial({ order: Schema.Int }),
]);
export type Game = Schema.TypeOf<typeof Game>;

/**
 * The details of a game with its bets.
 */
export const WithBets = Schema.intersection([
  Game,
  Schema.readonly(
    Schema.strict({
      bets: Schema.readonlyArray(
        Schema.tuple([
          LockMoments.Slug,
          Schema.string,
          Schema.readonlyArray(Schema.tuple([Bets.Slug, Bets.Bet])),
        ]),
      ),
    }),
  ),
]);
export type WithBets = Schema.TypeOf<typeof WithBets>;

/**
 * The details of a game with summarised bet statistics.
 */
export const WithBetStats = Schema.intersection([
  Game,
  Schema.readonly(
    Schema.strict({
      bets: Schema.Int,
      staked: Schema.Int,
    }),
  ),
]);
export type WithBetStats = Schema.TypeOf<typeof WithBetStats>;

/**
 * The library of games with bets.
 */
export const Library = Schema.readonly(
  Schema.strict({
    future: Schema.readonlyArray(Schema.tuple([Slug, WithBetStats])),
    current: Schema.readonlyArray(Schema.tuple([Slug, WithBetStats])),
    finished: Schema.readonlyArray(Schema.tuple([Slug, WithBetStats])),
  }),
);
export type Library = Schema.TypeOf<typeof Library>;

export const unknownProgress = Expect.exhaustive(
  "game progress",
  (i: Internal.Games.Progress) => i,
);

const progressFromInternal = (internal: Internal.Game): Progress => {
  switch (internal.progress) {
    case "Future":
      return { state: "Future" };

    case "Current":
      if (internal.started === null) {
        // We have an SQL check constraint, so this should never happen.
        throw new Error("Must have start to be current.");
      }
      return {
        state: "Current",
        start: internal.started,
      };

    case "Finished":
      if (internal.started === null || internal.finished === null) {
        // We have an SQL check constraint, so this should never happen.
        throw new Error("Must have start and finish to be finished.");
      }
      return {
        state: "Finished",
        start: internal.started,
        finish: internal.finished,
      };

    default:
      return unknownProgress(internal.progress);
  }
};

export const fromInternal = (internal: Internal.Game): [Slug, Game] => [
  internal.slug,
  {
    name: internal.name,
    cover: internal.cover,
    progress: progressFromInternal(internal),
    ...(internal.order !== null ? { order: internal.order } : {}),
    version: internal.version,
    created: internal.created,
    modified: internal.modified,
    managers: internal.managers.map(Users.summaryFromInternal),
  },
];

export const withBetStatsFromInternal = (
  internal: Internal.Game & Internal.Games.BetStats,
): [Slug, WithBetStats] => [
  internal.slug,
  {
    ...fromInternal(internal)[1],
    bets: internal.bets,
    staked: internal.staked,
  },
];

export const withBetsFromInternal = (
  internal: Internal.Game & Internal.Games.WithBets,
): [Slug, WithBets] => {
  const betsByLockMoment = [
    ...Iterables.groupBy((bet) => bet.lock_moment_slug, internal.bets),
  ];
  return [
    internal.slug,
    {
      ...fromInternal(internal)[1],
      bets: betsByLockMoment.map(([lockMomentSlug, bets]) => [
        lockMomentSlug,
        bets[0]?.lock_moment_name ?? "",
        bets.map(Bets.fromInternal),
      ]),
    },
  ];
};

export * as Games from "./games.js";
