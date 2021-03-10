import { DocumentReference } from "@google-cloud/firestore";

import { Stake } from "./stakes";

export interface Bankruptcy {
  event: "Bankruptcy";
}

export interface StakeCommitted {
  event: "StakeCommitted";
  bet: DocumentReference;
  option: string;
  stake?: Stake;
}

export interface Refund {
  event: "Refund";
  bet: DocumentReference;
  name: string;
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

export type LogEvent = Bankruptcy | StakeCommitted | Refund | Payout | Loss;

export * as EventLog from "./event-log";
