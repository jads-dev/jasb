import { z } from "zod";

import { zonedDateTime } from "./types.js";

export const Gifted = z
  .object({
    type: z.literal("Gifted"),
    amount: z.number().int().positive(),
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

const optionReference = z.object({
  gameId: z.string(),
  gameName: z.string(),
  betId: z.string(),
  betName: z.string(),
  optionId: z.string(),
  optionName: z.string(),
});

export const Refunded = z
  .object({
    type: z.literal("Refunded"),
    reason: z.enum(["OptionRemoved", "BetCancelled"]),
    amount: z.number().int().positive(),
  })
  .merge(optionReference)
  .strict();
export type Refunded = z.infer<typeof Refunded>;

export const BetFinished = z
  .object({
    type: z.literal("BetFinished"),
    result: z.enum(["Win", "Loss"]),
    amount: z.number().int(),
  })
  .merge(optionReference)
  .strict();
export type BetFinished = z.infer<typeof BetFinished>;

export const BetReverted = z
  .object({
    type: z.literal("BetReverted"),
    reverted: z.enum(["Complete", "Cancelled"]),
    amount: z.number().int(),
  })
  .merge(optionReference)
  .strict();
export type BetReverted = z.infer<typeof BetReverted>;

export const Message = z.discriminatedUnion("type", [
  Gifted,
  Refunded,
  BetFinished,
  BetReverted,
]);
export type Message = z.infer<typeof Message>;

export const Notification = z
  .object({
    id: z.number().int(),
    notification: Message,
    happened: zonedDateTime,
    read: z.boolean(),
  })
  .strict();
export type Notification = z.infer<typeof Notification>;

export * as Notifications from "./notifications.js";
