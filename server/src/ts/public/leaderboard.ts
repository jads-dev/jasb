import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Users } from "./users.js";

/**
 * The base for a leaderboard entry.
 */
const Entry = Schema.readonly(
  Schema.intersection([
    Users.Summary,
    Schema.strict({
      id: Users.Slug,
      rank: Schema.Int,
    }),
  ]),
);
type Entry = Schema.TypeOf<typeof Entry>;

/**
 * A leaderboard entry showing the user's net worth.
 */
export const NetWorthEntry = Schema.readonly(
  Schema.intersection([
    Entry,
    Schema.strict({
      netWorth: Schema.Int,
    }),
  ]),
);
export type NetWorthEntry = Schema.TypeOf<typeof NetWorthEntry>;

/**
 * A leaderboard entry showing the user's net worth.
 */
export const DebtEntry = Schema.readonly(
  Schema.intersection([
    Entry,
    Schema.strict({
      debt: Schema.Int,
    }),
  ]),
);
export type DebtEntry = Schema.TypeOf<typeof DebtEntry>;

const baseFromInternal = (internal: Internal.Users.Leaderboard): Entry => ({
  id: internal.slug,

  name: internal.name,
  ...(internal.discriminator !== null
    ? { discriminator: internal.discriminator }
    : {}),
  avatar: internal.avatar_url,

  rank: internal.rank as Schema.Int,
});

export const netWorthEntryFromInternal = (
  internal: Internal.Users.Leaderboard,
): NetWorthEntry => ({
  ...baseFromInternal(internal),
  netWorth: internal.net_worth as Schema.Int,
});

export const debtEntryFromInternal = (
  internal: Internal.Users.Leaderboard,
): DebtEntry => ({
  ...baseFromInternal(internal),
  debt: internal.balance as Schema.Int,
});

export * as Leaderboard from "./leaderboard.js";
