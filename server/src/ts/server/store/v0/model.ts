import { DocumentReference, Timestamp } from "@google-cloud/firestore";

export interface User {
  name: string;
  discriminator: string;
  avatar?: string;
  score: number;
  admin?: true;
  accessToken: string;
  refreshToken: string;
}

export type Game = {
  name: string;
  igdbImageId: string;
  bets: number;
  future?: true;
  start?: Timestamp;
  finish?: Timestamp;
};

export interface Option {
  id: string;
  name: string;
  votes: string[];
}

export interface Voting {
  state: "Voting";
}

export interface Locked {
  state: "Locked";
}

export interface Complete {
  state: "Complete";
  winner: string;
}

export type Progress = Voting | Locked | Complete;

export interface Bet {
  id: string;
  name: string;
  game: DocumentReference;
  description: string;
  options: Option[];
  progress: Progress;
  spoiler: boolean;
}

export * as V0 from "./model";
