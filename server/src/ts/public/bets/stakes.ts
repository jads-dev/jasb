import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Validation } from "../../util/validation.js";
import { Users } from "../users/core.js";
import { Gacha } from "../gacha.js";

/**
 * A payout on a stake on a completed bet.
 */
export const Payout = Schema.readonly(
  Schema.partial({
    amount: Schema.Int,
    gacha: Gacha.Value,
  }),
);
export type Payout = Schema.TypeOf<typeof Payout>;

export const payoutFromInternal = (
  internal: Internal.Stakes.Stake,
): Payout | null => {
  const amount = internal.payout?.amount;
  const gacha = internal.payout?.gacha
    ? Gacha.Balances.valueFromInternal(internal.payout?.gacha)
    : null;
  const result = {
    ...(amount ? { amount } : {}),
    ...(gacha !== null && (gacha.guarantees || gacha.rolls || gacha.scrap)
      ? { gacha }
      : {}),
  };
  return result.amount || result.gacha ? result : null;
};

/**
 * A stake on an option on the bet, by a user.
 */
export const Stake = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      user: Users.Summary,
      at: Validation.DateTime,
      amount: Schema.Int,
    }),
    Schema.partial({
      message: Schema.string,
      payout: Payout,
    }),
  ]),
);
export type Stake = Schema.TypeOf<typeof Stake>;

export const fromInternal = (
  internal: Internal.Stakes.Stake,
): [Users.Slug, Stake] => {
  const payout = payoutFromInternal(internal);
  return [
    internal.user.slug,
    {
      user: {
        name: internal.user.name,
        ...(internal.user.discriminator !== null
          ? { discriminator: internal.user.discriminator }
          : {}),
        avatar: internal.user.avatar_url,
      },
      at: internal.made_at,
      amount: internal.amount,
      ...(internal.message !== null ? { message: internal.message } : {}),
      ...(payout !== null ? { payout } : {}),
    },
  ];
};

export * as Stakes from "./stakes.js";
