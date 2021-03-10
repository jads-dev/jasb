import { Timestamp } from "@google-cloud/firestore";

import { Internal } from "../internal";

export interface Stake {
  amount: number;
  at: number;
}

export const toInternal = (stake: Stake): Internal.Stake => ({
  amount: stake.amount,
  at: new Timestamp(stake.at, 0),
});

export const fromInternal = (internal: Internal.Stake): Stake => ({
  amount: internal.amount,
  at: internal.at.seconds,
});

export * as Stakes from "./stakes";
