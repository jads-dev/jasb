import { Stake } from "./stakes";

export interface HistoricAccount {
  event: "HistoricAccount";
  balance: number;
  betValue: number;
}

export interface CreateAccount {
  event: "CreateAccount";
  balance: number;
}

export interface Bankruptcy {
  event: "Bankruptcy";
  balance: number;
}

export interface StakeCommitted {
  event: "StakeCommitted";
  game: string;
  bet: string;
  option: string;
  stake: Stake;
}

export interface StakeWithdrawn {
  event: "StakeWithdrawn";
  game: string;
  bet: string;
  option: string;
  amount: number;
}

export interface Refund {
  event: "Refund";
  game: string;
  bet: string;
  option: string;
  optionName: string;
  stake: Stake;
}

export interface Payout {
  event: "Payout";
  game: string;
  bet: string;
  option: string;
  stake: Stake;
  winnings: number;
}

export interface Loss {
  event: "Loss";
  game: string;
  bet: string;
  option: string;
  stake: Stake;
}

export type Event =
  | HistoricAccount
  | CreateAccount
  | Bankruptcy
  | StakeCommitted
  | StakeWithdrawn
  | Refund
  | Payout
  | Loss;

export interface Entry {
  id: string;
  user: string;
  happened: string;
  event: Event;
}

export * as AuditLog from "./audit-log";
