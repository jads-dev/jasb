import { Timestamp } from "@google-cloud/firestore";

export interface Stake {
  amount: number;
  at: Timestamp;
}

export * as Stakes from "./stakes";
