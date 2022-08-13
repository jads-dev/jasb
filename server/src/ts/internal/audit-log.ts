import { z } from "zod";

import { Stake } from "./stakes.js";
import { zonedDateTime } from "./types.js";

export const HistoricAccount = z
  .object({
    event: z.literal("HistoricAccount"),
    balance: z.number().int(),
    betValue: z.number().int(),
  })
  .strict();
export type HistoricAccount = z.infer<typeof HistoricAccount>;

export const CreateAccount = z
  .object({
    event: z.literal("CreateAccount"),
    balance: z.number().int().positive(),
  })
  .strict();
export type CreateAccount = z.infer<typeof CreateAccount>;

export const Bankruptcy = z
  .object({
    event: z.literal("Bankruptcy"),
    balance: z.number().int().positive(),
  })
  .strict();
export type Bankruptcy = z.infer<typeof Bankruptcy>;

export const StakeCommitted = z
  .object({
    event: z.literal("StakeCommitted"),
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    stake: Stake,
  })
  .strict();
export type StakeCommitted = z.infer<typeof StakeCommitted>;

export const StakeWithdrawn = z
  .object({
    event: z.literal("StakeWithdrawn"),
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    amount: z.number().int().positive(),
  })
  .strict();
export type StakeWithdrawn = z.infer<typeof StakeWithdrawn>;

export const Refund = z
  .object({
    event: z.literal("Refund"),
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    optionName: z.string(),
    stake: Stake,
  })
  .strict();
export type Refund = z.infer<typeof Refund>;

export const Payout = z
  .object({
    event: z.literal("Payout"),
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    stake: Stake,
    winnings: z.number().int().positive(),
  })
  .strict();
export type Payout = z.infer<typeof Payout>;

export const Loss = z
  .object({
    event: z.literal("Loss"),
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    stake: z.number().int().positive(),
  })
  .strict();
export type Loss = z.infer<typeof Loss>;

export const Revert = z
  .object({
    event: z.literal("Revert"),
    game: z.string(),
    bet: z.string(),
    option: z.string(),
    reverted: z.enum(["Complete", "Cancelled"]),
    amount: z.number().int().positive(),
  })
  .strict();
export type Revert = z.infer<typeof Revert>;

export const Event = z.discriminatedUnion("event", [
  HistoricAccount,
  CreateAccount,
  Bankruptcy,
  StakeCommitted,
  StakeWithdrawn,
  Refund,
  Payout,
  Loss,
  Revert,
]);
export type Event = z.infer<typeof Event>;

export const Entry = z
  .object({
    id: z.string(),
    user: z.string(),
    happened: zonedDateTime,
    event: Event,
  })
  .strict();
export type Entry = z.infer<typeof Entry>;

export * as AuditLog from "./audit-log.js";
