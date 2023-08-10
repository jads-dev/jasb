import { z } from "zod";

import { Types } from "./types.js";

export const GachaAmount = z
  .object({ rolls: Types.int, scrap: Types.int })
  .strict();
export type GachaAmount = z.infer<typeof GachaAmount>;

export const Gifted = z
  .object({
    type: z.literal("Gifted"),
    amount: Types.positiveInt,
    reason: z.union([
      z.enum(["AccountCreated", "Bankruptcy"]),
      z
        .object({
          special: z.string(),
        })
        .strict(),
    ]),
  })
  .strict();
export type Gifted = z.infer<typeof Gifted>;

export const OptionReference = z.object({
  game_slug: Types.gameSlug,
  game_name: z.string(),
  bet_slug: Types.betSlug,
  bet_name: z.string(),
  option_slug: Types.optionSlug,
  option_name: z.string(),
});
export type OptionReference = z.infer<typeof OptionReference>;

export const Refunded = z
  .object({
    type: z.literal("Refunded"),
    reason: z.enum(["OptionRemoved", "BetCancelled"]),
    amount: Types.positiveInt,
  })
  .merge(OptionReference)
  .strict();
export type Refunded = z.infer<typeof Refunded>;

export const BetFinished = z
  .object({
    type: z.literal("BetFinished"),
    result: z.enum(["Win", "Loss"]),
    amount: Types.int,
    gacha_amount: GachaAmount.optional(),
  })
  .merge(OptionReference)
  .strict();
export type BetFinished = z.infer<typeof BetFinished>;

export const BetReverted = z
  .object({
    type: z.literal("BetReverted"),
    reverted: z.enum(["Complete", "Cancelled"]),
    amount: Types.int,
    gacha_amount: GachaAmount.optional(),
  })
  .merge(OptionReference)
  .strict();
export type BetReverted = z.infer<typeof BetReverted>;

export const GachaGifted = z
  .object({
    type: z.literal("GachaGifted"),
    amount: GachaAmount,
    reason: z.union([
      z.enum(["Historic"]),
      z
        .object({
          special: z.string(),
        })
        .strict(),
    ]),
  })
  .strict();
export type GachaGifted = z.infer<typeof Gifted>;

export const GachaGiftedCard = z
  .object({
    type: z.literal("GachaGiftedCard"),
    banner: Types.bannerSlug,
    card: Types.cardId,
    reason: z.union([
      z.enum(["SelfMade"]),
      z
        .object({
          special: z.string(),
        })
        .strict(),
    ]),
  })
  .strict();
export type GachaGiftedCard = z.infer<typeof GachaGiftedCard>;

export const Message = z.discriminatedUnion("type", [
  Gifted,
  Refunded,
  BetFinished,
  BetReverted,
  GachaGifted,
  GachaGiftedCard,
]);
export type Message = z.infer<typeof Message>;

export const Notification = z
  .object({
    id: Types.notificationId,
    notification: Message,
  })
  .strict();
export type Notification = z.infer<typeof Notification>;

export * as Notifications from "./notifications.js";
