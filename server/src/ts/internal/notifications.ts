import * as Joda from "@js-joda/core";

export interface Gifted {
  type: "Gifted";
  amount: number;
  reason: "AccountCreated" | "Bankruptcy";
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

export interface BetReverted {
  type: "BetReverted";
  gameId: string;
  gameName: string;
  betId: string;
  betName: string;
  optionId: string;
  optionName: string;
  reverted: "Complete" | "Cancelled";
  amount: number;
}

export type Message = Gifted | Refunded | BetFinished | BetReverted;

export interface Notification {
  id: number;
  notification: Message;
  at: Joda.ZonedDateTime;
  read: boolean;
}

export * as Notifications from "./notifications.js";
