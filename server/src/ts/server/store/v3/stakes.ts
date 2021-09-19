import { Timestamp } from "@google-cloud/firestore";

export interface Stake {
  amount: number;
  at: Timestamp;
  locked?: true;
}

export * as Stakes from "./stakes";
