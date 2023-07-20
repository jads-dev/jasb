import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Validation } from "../../util/validation.js";
import { Users } from "../users/id.js";

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
    }),
  ]),
);
export type Stake = Schema.TypeOf<typeof Stake>;

export const fromInternal = (
  internal: Internal.Stakes.Stake,
): [Users.Id, Stake] => [
  internal.user.slug as Users.Id,
  {
    user: {
      name: internal.user.name,
      ...(internal.user.discriminator !== null
        ? { discriminator: internal.user.discriminator }
        : {}),
      avatar: internal.user.avatar_url,
    },
    at: internal.made_at,
    amount: internal.amount as Schema.Int,
    ...(internal.message !== null ? { message: internal.message } : {}),
  },
];

export * as Stakes from "./stakes.js";
