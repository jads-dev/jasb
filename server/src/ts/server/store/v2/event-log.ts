import { DocumentReference, Timestamp } from "@google-cloud/firestore";

import { Stake } from "../v2";

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
  bet: DocumentReference;
  option: string;
  stake: Stake;
}

export interface StakeWithdrawn {
  event: "StakeWithdrawn";
  bet: DocumentReference;
  option: string;
  amount: number;
}

export interface Refund {
  event: "Refund";
  bet: DocumentReference;
  option: string;
  optionName: string;
  stake: Stake;
}

export interface Payout {
  event: "Payout";
  bet: DocumentReference;
  option: string;
  stake: Stake;
  winnings: number;
}

export interface Loss {
  event: "Loss";
  bet: DocumentReference;
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
  event: Event;
  at: Timestamp;
}

export * as EventLog from "./event-log";
