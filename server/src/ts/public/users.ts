import { Internal } from "../internal";
import { Games } from "./games";

export type Id = string;

export interface User {
  name: string;
  discriminator: string;
  avatar?: string;

  balance: number;
  betValue: number;

  created: number;
  admin?: true;
  mod?: Games.Id[];
}

export interface WithId {
  id: string;
  user: User;
}

export const fromInternal = (internal: Internal.User): User => ({
  name: internal.name,
  discriminator: internal.discriminator,
  avatar: internal.avatar,

  balance: internal.balance,
  betValue: internal.betValue,

  created: internal.created.seconds,
  ...(internal.admin ? { admin: true } : {}),
  ...(internal.mod ? { mod: internal.mod } : {}),
});

export * as Users from "./users";
