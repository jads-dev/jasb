import { z } from "zod";

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

export const OptionReference = z.object({
  game_slug: z.string(),
  game_name: z.string(),
  bet_slug: z.string(),
  bet_name: z.string(),
  option_slug: z.string(),
  option_name: z.string(),
});
export type OptionReference = z.infer<typeof OptionReference>;

export const Refunded = z
  .object({
    type: z.literal("Refunded"),
    reason: z.enum(["OptionRemoved", "BetCancelled"]),
    amount: z.number().int().positive(),
  })
  .merge(OptionReference)
  .strict();
export type Refunded = z.infer<typeof Refunded>;

export const BetFinished = z
  .object({
    type: z.literal("BetFinished"),
    result: z.enum(["Win", "Loss"]),
    amount: z.number().int(),
  })
  .merge(OptionReference)
  .strict();
export type BetFinished = z.infer<typeof BetFinished>;

export const BetReverted = z
  .object({
    type: z.literal("BetReverted"),
    reverted: z.enum(["Complete", "Cancelled"]),
    amount: z.number().int(),
  })
  .merge(OptionReference)
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
  })
  .strict();
export type Notification = z.infer<typeof Notification>;

export * as Notifications from "./notifications.js";
