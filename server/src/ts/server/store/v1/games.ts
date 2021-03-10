import { Timestamp } from "@google-cloud/firestore";

export interface Future {
  state: "Future";
}

export interface Current {
  state: "Current";
  start: Timestamp;
}

export interface Finished {
  state: "Finished";
  start: Timestamp;
  finish: Timestamp;
}

export type Progress = Future | Current | Finished;

export interface Game {
  name: string;
  cover: string;

  bets: number;

  progress: Progress;
}

export * as Games from "./games";
