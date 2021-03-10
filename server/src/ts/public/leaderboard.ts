import { Internal } from "../internal";
import { Users } from "./users";

export interface Entry {
  id: Users.Id;

  name: string;
  discriminator: string;
  avatar?: string;

  netWorth: number;
}

export const fromInternal = (id: string, internal: Internal.User): Entry => ({
  id,

  name: internal.name,
  discriminator: internal.discriminator,
  avatar: internal.avatar,

  netWorth: internal.netWorth,
});

export * as Leaderboard from "./leaderboard";
