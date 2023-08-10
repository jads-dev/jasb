import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Expect } from "../util/expect.js";
import { Validation } from "../util/validation.js";
import { Bets } from "./bets.js";
import { Options } from "./bets/options.js";
import { Banners } from "./gacha/banners.js";
import { Cards } from "./gacha/cards.js";
import { Games } from "./games.js";

/**
 * An ID for a notification.
 */
interface NotificationIdBrand {
  readonly NotificationId: unique symbol;
}
export const Id = Validation.Id("NotificationId")<NotificationIdBrand>();
export type Id = Schema.TypeOf<typeof Id>;

export const GachaAmount = Schema.partial({
  rolls: Schema.Int,
  scrap: Schema.Int,
});
export type GachaAmount = Schema.TypeOf<typeof GachaAmount>;

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
    gameId: Games.Slug,
    gameName: Schema.string,
    betId: Bets.Slug,
    betName: Schema.string,
    optionId: Options.Slug,
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
  Schema.readonly(
    Schema.partial({
      gachaAmount: GachaAmount,
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
  Schema.readonly(
    Schema.partial({
      gachaAmount: GachaAmount,
    }),
  ),
]);
export type BetReverted = Schema.TypeOf<typeof BetReverted>;

/**
 * A notification the user has been gifted gacha balance.
 */
export const GachaGifted = Schema.readonly(
  Schema.strict({
    id: Id,
    type: Schema.literal("GachaGifted"),
    amount: GachaAmount,
    reason: Schema.union([
      Schema.keyof({
        Historic: null,
      }),
      Schema.readonly(Schema.strict({ special: Schema.string })),
    ]),
  }),
);
export type GachaGifted = Schema.TypeOf<typeof GachaGifted>;

/**
 * A notification the user has been gifted gacha balance.
 */
export const GachaGiftedCard = Schema.readonly(
  Schema.strict({
    id: Id,
    type: Schema.literal("GachaGiftedCard"),
    banner: Banners.Slug,
    card: Cards.Id,
    reason: Schema.union([
      Schema.keyof({
        SelfMade: null,
      }),
      Schema.readonly(Schema.strict({ special: Schema.string })),
    ]),
  }),
);
export type GachaGiftedCard = Schema.TypeOf<typeof GachaGiftedCard>;

/**
 * A notification for the user about something that happened.
 */
export const Notification = Schema.union([
  Gifted,
  Refunded,
  BetFinished,
  BetReverted,
  GachaGifted,
  GachaGiftedCard,
]);
export type Notification = Schema.TypeOf<typeof Notification>;

export const unknownNotification = Expect.exhaustive(
  "notification type",
  (i: Internal.Notifications.Message) => i.type,
);

const optionReferenceFromInternal = (
  internal: Internal.Notifications.OptionReference,
): OptionReference => ({
  gameId: internal.game_slug,
  gameName: internal.game_name,
  betId: internal.bet_slug,
  betName: internal.bet_name,
  optionId: internal.option_slug,
  optionName: internal.option_name,
});

const gachaAmountFromInternal = (
  internal: Internal.Notifications.GachaAmount,
): GachaAmount => ({
  ...(internal.rolls !== undefined && internal.rolls > 0
    ? { rolls: internal.rolls }
    : {}),
  ...(internal.scrap !== undefined && internal.scrap > 0
    ? { scrap: internal.scrap }
    : {}),
});

export const fromInternal = (internal: Internal.Notification): Notification => {
  const { id, notification } = internal;
  switch (notification.type) {
    case "Gifted":
      return {
        id: id,
        type: "Gifted",
        amount: notification.amount,
        reason: notification.reason,
      };
    case "Refunded":
      return {
        id: id,
        type: "Refunded",
        ...optionReferenceFromInternal(notification),
        reason: notification.reason,
        amount: notification.amount,
      };
    case "BetFinished":
      return {
        id: id,
        type: "BetFinished",
        ...optionReferenceFromInternal(notification),
        result: notification.result,
        amount: notification.amount,
        ...(notification.gacha_amount
          ? { gachaAmount: gachaAmountFromInternal(notification.gacha_amount) }
          : {}),
      };
    case "BetReverted":
      return {
        id: id,
        type: "BetReverted",
        ...optionReferenceFromInternal(notification),
        reverted: notification.reverted,
        amount: notification.amount,
        ...(notification.gacha_amount
          ? { gachaAmount: gachaAmountFromInternal(notification.gacha_amount) }
          : {}),
      };
    case "GachaGifted":
      return {
        id: id,
        type: "GachaGifted",
        amount: gachaAmountFromInternal(notification.amount),
        reason: notification.reason,
      };
    case "GachaGiftedCard":
      return {
        id: id,
        type: "GachaGiftedCard",
        banner: notification.banner,
        card: notification.card,
        reason: notification.reason,
      };
    default:
      return unknownNotification(notification);
  }
};

export * as Notifications from "./notifications.js";
