import type { Internal } from "../internal.js";
import type { Users } from "../public.js";

export interface Entry {
  id: Users.Id;

  name: string;
  discriminator?: string;
  avatar?: string;
  avatar_cache?: string;

  rank: number;
}

export interface NetWorth {
  netWorth: number;
}

export type NetWorthEntry = Entry & NetWorth;

export interface Debt {
  debt: number;
}

export type DebtEntry = Entry & Debt;

const baseFromInternal = (
  internal: Internal.User & Internal.Users.Leaderboard,
): Entry => ({
  id: internal.id as Users.Id,

  name: internal.name,
  ...(internal.discriminator !== null
    ? { discriminator: internal.discriminator }
    : {}),
  ...(internal.avatar !== null ? { avatar: internal.avatar } : {}),
  ...(internal.avatar_cache !== null
    ? { avatarCache: internal.avatar_cache }
    : {}),

  rank: internal.rank,
});

export const netWorthEntryFromInternal = (
  internal: Internal.User &
    Internal.Users.BetStats &
    Internal.Users.Leaderboard,
): NetWorthEntry => ({
  ...baseFromInternal(internal),
  netWorth: internal.net_worth,
});

export const debtEntryFromInternal = (
  internal: Internal.User & Internal.Users.Leaderboard,
): DebtEntry => ({
  ...baseFromInternal(internal),
  debt: internal.balance,
});

export * as Leaderboard from "./leaderboard.js";
