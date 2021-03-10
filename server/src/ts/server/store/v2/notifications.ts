import { Timestamp } from "@google-cloud/firestore";

export interface Gifted {
  type: "Gifted";
  amount: number;
  reason: "AccountCreated";
}

export interface Refunded {
  type: "Refunded";
  gameId: string;
  gameName: string;
  betId: string;
  betName: string;
  optionId: string;
  optionName: string;
  reason: "OptionRemoved" | "BetCancelled";
  amount: number;
}

export interface BetFinished {
  type: "BetFinished";
  gameId: string;
  gameName: string;
  betId: string;
  betName: string;
  optionId: string;
  optionName: string;
  result: "Win" | "Loss";
  amount: number;
}

export type Message = Gifted | Refunded | BetFinished;

export interface Notification {
  message: Message;
  at: Timestamp;
}

export * as Notifications from "./notifications";
