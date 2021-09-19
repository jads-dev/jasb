import type { Internal } from "../internal";
import { Users } from ".";

export interface Entry {
  id: Users.Id;

  name: string;
  discriminator: string;
  avatar?: string;

  rank: number;
  netWorth: number;
}

export const fromInternal = (
  internal: Internal.User & Internal.Users.BetStats & Internal.Users.Leaderboard
): Entry => ({
  id: internal.id as Users.Id,

  name: internal.name,
  discriminator: internal.discriminator,
  ...(internal.avatar !== null ? { avatar: internal.avatar } : {}),

  rank: internal.rank,
  netWorth: internal.net_worth,
});

export * as Leaderboard from "./leaderboard";
