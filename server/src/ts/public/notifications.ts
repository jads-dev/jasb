import { Internal } from "../internal";
import { Expect } from "../util/expect";

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

export type Notification = Gifted | Refunded | BetFinished;

export const unknownNotification = Expect.exhaustive(
  "notification type",
  (i: Internal.Notifications.Message) => i.type
);

export const fromInternal = (internal: Internal.Notification): Notification => {
  const { message } = internal;
  switch (message.type) {
    case "Gifted":
      return {
        type: "Gifted",
        amount: message.amount,
        reason: message.reason,
      };
    case "Refunded":
      return {
        type: "Refunded",
        gameId: message.gameId,
        gameName: message.gameName,
        betId: message.betId,
        betName: message.betName,
        optionId: message.optionId,
        optionName: message.optionName,
        reason: message.reason,
        amount: message.amount,
      };
    case "BetFinished":
      return {
        type: "BetFinished",
        gameId: message.gameId,
        gameName: message.gameName,
        betId: message.betId,
        betName: message.betName,
        optionId: message.optionId,
        optionName: message.optionName,
        result: message.result,
        amount: message.amount,
      };
    default:
      return unknownNotification(message);
  }
};

export * as Notifications from "./notifications";
