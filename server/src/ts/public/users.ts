import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import type { Games } from "./games.js";

interface UserIdBrand {
  readonly UserId: unique symbol;
}

export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, UserIdBrand> => true,
  "UserId",
);
export type Id = Schema.TypeOf<typeof Id>;

export interface User {
  name: string;
  discriminator: string;
  avatar?: string;
  avatarCache?: string;

  balance: number;
  betValue: number;

  created: string;
  admin?: true;
  mod?: Games.Id[];
}

export interface WithId {
  id: Id;
  user: User;
}

export interface Summary {
  name: string;
  discriminator: string;
  avatar?: string;
  avatar_cache?: string;
}

export interface BankruptcyStats {
  amountLost: number;
  stakesLost: number;
  lockedStakesLost: number;
  lockedAmountLost: number;
  balanceAfter: number;
}

export interface Permissions {
  gameId: Games.Id;
  gameName: string;
  canManageBets: boolean;
}

export const fromInternal = (
  internal: Internal.User &
    Internal.Users.Permissions &
    Internal.Users.BetStats,
): WithId => ({
  id: internal.id as Id,
  user: {
    name: internal.name,
    discriminator: internal.discriminator,
    ...(internal.avatar !== null ? { avatar: internal.avatar } : {}),
    ...(internal.avatar_cache !== null
      ? { avatarCache: internal.avatar_cache }
      : {}),

    balance: internal.balance,
    betValue: internal.staked,

    created: internal.created.toJSON(),
    ...(internal.admin ? { admin: true } : {}),
    mod: internal.moderator_for as Games.Id[],
  },
});

export const summaryFromInternal = (
  internal: Internal.Users.Summary,
): [Id, Summary] => [
  internal.id as Id,
  {
    name: internal.name,
    discriminator: internal.discriminator,
    ...(internal.avatar !== null ? { avatar: internal.avatar } : {}),
    ...(internal.avatar_cache !== null
      ? { avatarCache: internal.avatar_cache }
      : {}),
  },
];

export const bankruptcyStatsFromInternal = ({
  amount_lost,
  stakes_lost,
  locked_amount_lost,
  locked_stakes_lost,
  balance_after,
}: Internal.Users.BankruptcyStats): BankruptcyStats => ({
  amountLost: amount_lost,
  stakesLost: stakes_lost,
  lockedAmountLost: locked_amount_lost,
  lockedStakesLost: locked_stakes_lost,
  balanceAfter: balance_after,
});

export const permissionsFromInternal = ({
  game_id,
  game_name,
  manage_bets,
}: Internal.Users.PerGamePermissions): Permissions => ({
  gameId: game_id as Games.Id,
  gameName: game_name,
  canManageBets: manage_bets,
});

export * as Users from "./users.js";
