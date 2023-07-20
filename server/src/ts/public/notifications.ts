import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import { Bets } from "./bets.js";
import { Options } from "./bets/options.js";
import { Games } from "./games.js";

/**
 * An ID for a notification, unlike most IDs this is the database ID, not a
 * slug, as there is no meaningful name for a notification.
 */
interface NotificationIdBrand {
  readonly NotificationId: unique symbol;
}
export const Id = Schema.brand(
  Schema.Int,
  (id): id is Schema.Branded<Schema.Int, NotificationIdBrand> => true,
  "NotificationId",
);
export type Id = Schema.TypeOf<typeof Id>;

/**
 * A notification the user has been gifted coins.
 */
export const Gifted = Schema.readonly(
  Schema.strict({
    id: Id,
    type: Schema.literal("Gifted"),
    amount: Schema.Int,
    reason: Schema.union([
      Schema.keyof({
        AccountCreated: null,
        Bankruptcy: null,
      }),
      Schema.readonly(Schema.strict({ special: Schema.string })),
    ]),
  }),
);
export type Gifted = Schema.TypeOf<typeof Gifted>;

const OptionReference = Schema.readonly(
  Schema.strict({
    gameId: Games.Id,
    gameName: Schema.string,
    betId: Bets.Id,
    betName: Schema.string,
    optionId: Options.Id,
    optionName: Schema.string,
  }),
);
type OptionReference = Schema.TypeOf<typeof OptionReference>;

/**
 * A notification the user has been refunded coins.
 */
export const Refunded = Schema.intersection([
  OptionReference,
  Schema.readonly(
    Schema.strict({
      id: Id,
      type: Schema.literal("Refunded"),
      reason: Schema.keyof({
        OptionRemoved: null,
        BetCancelled: null,
      }),
      amount: Schema.Int,
    }),
  ),
]);
export type Refunded = Schema.TypeOf<typeof Refunded>;

/**
 * A notification the user a bet they have a stake in has finished.
 */
export const BetFinished = Schema.intersection([
  OptionReference,
  Schema.readonly(
    Schema.strict({
      id: Id,
      type: Schema.literal("BetFinished"),
      result: Schema.keyof({
        Win: null,
        Loss: null,
      }),
      amount: Schema.Int,
    }),
  ),
]);
export type BetFinished = Schema.TypeOf<typeof BetFinished>;

/**
 * A notification the user a bet they had a stake in has had a result or
 * cancellation reverted.
 */
export const BetReverted = Schema.intersection([
  OptionReference,
  Schema.readonly(
    Schema.strict({
      id: Id,
      type: Schema.literal("BetReverted"),
      reverted: Schema.keyof({
        Complete: null,
        Cancelled: null,
      }),
      amount: Schema.Int,
    }),
  ),
]);
export type BetReverted = Schema.TypeOf<typeof BetReverted>;

/**
 * A notification for the user about something that happened.
 */
export const Notification = Schema.union([
  Gifted,
  Refunded,
  BetFinished,
  BetReverted,
]);
export type Notification = Schema.TypeOf<typeof Notification>;

export const unknownNotification = Expect.exhaustive(
  "notification type",
  (i: Internal.Notifications.Message) => i.type,
);

const optionReferenceFromInternal = (
  internal: Internal.Notifications.OptionReference,
): OptionReference => ({
  gameId: internal.game_slug as Games.Id,
  gameName: internal.game_name,
  betId: internal.bet_slug as Bets.Id,
  betName: internal.bet_name,
  optionId: internal.option_slug as Options.Id,
  optionName: internal.option_name,
});

export const fromInternal = (internal: Internal.Notification): Notification => {
  const { id, notification } = internal;
  switch (notification.type) {
    case "Gifted":
      return {
        id: id as Id,
        type: "Gifted",
        amount: notification.amount as Schema.Int,
        reason: notification.reason,
      };
    case "Refunded":
      return {
        id: id as Id,
        type: "Refunded",
        ...optionReferenceFromInternal(notification),
        reason: notification.reason,
        amount: notification.amount as Schema.Int,
      };
    case "BetFinished":
      return {
        id: id as Id,
        type: "BetFinished",
        ...optionReferenceFromInternal(notification),
        result: notification.result,
        amount: notification.amount as Schema.Int,
      };
    case "BetReverted":
      return {
        id: id as Id,
        type: "BetReverted",
        ...optionReferenceFromInternal(notification),
        reverted: notification.reverted,
        amount: notification.amount as Schema.Int,
      };
    default:
      return unknownNotification(notification);
  }
};

export * as Notifications from "./notifications.js";
