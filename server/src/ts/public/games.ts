import { Timestamp } from "@google-cloud/firestore";

import { Internal } from "../internal";
import { Expect } from "../util/expect";

export type Id = string;

export interface Future {
  state: "Future";
}

export interface Current {
  state: "Current";
  start: number;
}

export interface Finished {
  state: "Finished";
  start: number;
  finish: number;
}

export type Progress = Future | Current | Finished;

export interface Game {
  name: string;
  cover: string;

  bets: number;

  progress: Progress;
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
  (i: Internal.Games.Progress) => i.state
);

const progressToInternal = (progress: Progress): Internal.Games.Progress => {
  switch (progress.state) {
    case "Future":
      return { state: "Future" };

    case "Current":
      return { state: "Current", start: new Timestamp(progress.start, 0) };

    case "Finished":
      return {
        state: "Finished",
        start: new Timestamp(progress.start, 0),
        finish: new Timestamp(progress.finish, 0),
      };

    default:
      return unknownProgress(progress);
  }
};

export const toInternal = (game: Game): Internal.Game => ({
  name: game.name,
  cover: game.cover,

  bets: game.bets,

  progress: progressToInternal(game.progress),
});

const progressFromInternal = (internal: Internal.Games.Progress): Progress => {
  switch (internal.state) {
    case "Future":
      return { state: "Future" };

    case "Current":
      return { state: "Current", start: internal.start.seconds };

    case "Finished":
      return {
        state: "Finished",
        start: internal.start.seconds,
        finish: internal.finish.seconds,
      };

    default:
      return unknownProgress(internal);
  }
};

export const fromInternal = (internal: Internal.Game): Game => ({
  name: internal.name,
  cover: internal.cover,

  bets: internal.bets,

  progress: progressFromInternal(internal.progress),
});

export * as Games from "./games";
