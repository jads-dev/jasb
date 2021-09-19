import * as Joda from "@js-joda/core";
import type { Internal } from "../../internal";
import type { Users } from "../users";

export interface Stake {
  user: {
    name: string;
    discriminator: string;
    avatar?: string;
  };
  at: string;
  amount: number;
  message?: string;
}

export const fromInternal = (
  internal: Internal.Stakes.WithUser
): [Users.Id, Stake] => [
  internal.stake.owner as Users.Id,
  {
    user: {
      name: internal.user.name,
      discriminator: internal.user.discriminator,
      ...(internal.user.avatar !== null
        ? { avatar: internal.user.avatar }
        : {}),
    },
    at: Joda.ZonedDateTime.parse(internal.stake.made_at).toJSON(),
    amount: internal.stake.amount,
    ...(internal.stake.message !== null
      ? { message: internal.stake.message }
      : {}),
  },
];

export * as Stakes from "./stakes";
