import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import { Validation } from "../util/validation.js";
import { Bets } from "./bets.js";
import { Users } from "./users/id.js";

/**
 * An ID for a user from the perspective of the API user, this is the slug
 * internally.
 */
interface GameIdBrand {
  readonly GameId: unique symbol;
}
export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, GameIdBrand> => true,
  "GameId",
);
export type Id = Schema.TypeOf<typeof Id>;

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
      managers: Schema.readonlyArray(Schema.tuple([Users.Id, Users.Summary])),
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
      bets: Schema.readonlyArray(Schema.tuple([Bets.Id, Bets.Bet])),
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
    future: Schema.readonlyArray(Schema.tuple([Id, WithBetStats])),
    current: Schema.readonlyArray(Schema.tuple([Id, WithBetStats])),
    finished: Schema.readonlyArray(Schema.tuple([Id, WithBetStats])),
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
      return {
        state: "Current",
        // We have an SQL check constraint, so this is not null in this case.
        start: internal.started!,
      };

    case "Finished":
      return {
        state: "Finished",
        // We have an SQL check constraint, so these are not null in this case.
        start: internal.started!,
        finish: internal.finished!,
      };

    default:
      return unknownProgress(internal.progress);
  }
};

export const fromInternal = (internal: Internal.Game): [Id, Game] => [
  internal.slug as Id,
  {
    name: internal.name,
    cover: internal.cover,
    progress: progressFromInternal(internal),
    ...(internal.order !== null ? { order: internal.order as Schema.Int } : {}),
    version: internal.version as Schema.Int,
    created: internal.created,
    modified: internal.modified,
    managers: internal.managers.map(Users.summaryFromInternal),
  },
];

export const withBetStatsFromInternal = (
  internal: Internal.Game & Internal.Games.BetStats,
): [Id, WithBetStats] => [
  internal.slug as Id,
  {
    ...fromInternal(internal)[1],
    bets: internal.bets as Schema.Int,
    staked: internal.staked as Schema.Int,
  },
];

export const withBetsFromInternal = (
  internal: Internal.Game & Internal.Games.WithBets,
): [Id, WithBets] => [
  internal.slug as Id,
  {
    ...fromInternal(internal)[1],
    bets: internal.bets.map(Bets.fromInternal),
  },
];

export * as Games from "./games.js";
