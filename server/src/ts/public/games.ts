import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import { Bets } from "./bets.js";
import { Users } from "./users.js";

interface GameIdBrand {
  readonly GameId: unique symbol;
}

export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, GameIdBrand> => true,
  "GameId",
);
export type Id = Schema.TypeOf<typeof Id>;

export interface Future {
  state: "Future";
}

export interface Current {
  state: "Current";
  start: string;
}

export interface Finished {
  state: "Finished";
  start: string;
  finish: string;
}

export type Progress = Future | Current | Finished;

export interface Game {
  version: number;
  name: string;
  cover: string;
  igdbId: string;

  bets: number;

  progress: Progress;
  order?: number;
}

export type WithBets = Omit<Game, "bets"> & {
  bets: Bets.WithId[];
};

export interface Details {
  staked: number;
  mods: Record<Users.Id, Users.Summary>;
}

export interface WithId {
  id: Id;
  game: Game;
}

export interface Library {
  future: WithId[];
  current: WithId[];
  finished: WithId[];
}

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
        start: internal.started?.toJSON() as string,
      };

    case "Finished":
      return {
        state: "Finished",
        start: internal.started?.toJSON() as string,
        finish: internal.finished?.toJSON() as string,
      };

    default:
      return unknownProgress(internal.progress);
  }
};

export const fromInternal = (
  internal: Internal.Game & Internal.Games.BetStats,
): WithId => ({
  id: internal.id as Id,
  game: {
    version: internal.version,
    name: internal.name,
    cover: internal.cover,
    igdbId: internal.igdb_id,

    bets: internal.bets,

    progress: progressFromInternal(internal),
    ...(internal.order !== null ? { order: internal.order } : {}),
  },
});

export const detailedFromInternal = (
  internal: Internal.Game &
    Internal.Games.BetStats &
    Internal.Games.StakeStats &
    Internal.Games.Mods,
): { id: Id; game: Game & Details } => ({
  id: internal.id as Id,
  game: {
    version: internal.version,
    name: internal.name,
    cover: internal.cover,
    igdbId: internal.igdb_id,

    progress: progressFromInternal(internal),
    ...(internal.order !== null ? { order: internal.order } : {}),

    bets: internal.bets,
    staked: internal.staked,

    mods: Object.fromEntries(internal.mods.map(Users.summaryFromInternal)),
  },
});

export const withBetsFromInternal = (
  internal: Internal.Game & Internal.Games.EmbeddedBets,
): { id: Id; game: WithBets } => ({
  id: internal.id as Id,
  game: {
    version: internal.version,
    name: internal.name,
    cover: internal.cover,
    igdbId: internal.igdb_id,

    progress: progressFromInternal(internal),

    bets: internal.bets.map(Bets.fromInternal),
  },
});

export * as Games from "./games.js";
