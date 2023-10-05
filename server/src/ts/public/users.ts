import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Validation } from "../util/validation.js";
import { Games } from "./games.js";
import { Slug } from "./users/core.js";

/**
 * Indicates permissions to manage all resources of the type.
 */
const All = Schema.literal("*");

/**
 * Indicates the permission applies to a specific game.
 */
const Game = Schema.strict({ id: Games.Slug, name: Schema.string });

/**
 * The permissions for a user so the UI can present the right options for a
 * user.
 */
export const Permissions = Schema.readonly(
  Schema.partial({
    manageGames: Schema.readonlyArray(All),
    managePermissions: Schema.readonlyArray(All),
    manageGacha: Schema.readonlyArray(All),
    manageBets: Schema.readonlyArray(Schema.union([All, Game])),
  }),
);
export type Permissions = Schema.TypeOf<typeof Permissions>;

/**
 * Full details of a user.
 */
export const User = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      name: Schema.string,
      avatar: Schema.string,
      balance: Schema.Int,
      betValue: Schema.Int,
      created: Validation.DateTime,
    }),
    Schema.partial({
      discriminator: Schema.string,
      permissions: Permissions,
    }),
  ]),
);
export type User = Schema.TypeOf<typeof User>;

/**
 * Stats for telling the user about what will happen if they go bankrupt.
 */
export const BankruptcyStats = Schema.readonly(
  Schema.strict({
    amountLost: Schema.Int,
    stakesLost: Schema.Int,
    lockedStakesLost: Schema.Int,
    lockedAmountLost: Schema.Int,
    balanceAfter: Schema.Int,
  }),
);
export type BankruptcyStats = Schema.TypeOf<typeof BankruptcyStats>;

const manageFromInternal = (manage: boolean) => (manage ? ["*" as const] : []);

const manageBetsFromInternal = (
  manageBets: boolean,
  manageBetsGames: readonly { slug: Games.Slug; name: string }[],
): Exclude<Permissions["manageBets"], undefined> => [
  ...(manageBets ? ["*" as const] : []),
  ...manageBetsGames.map(({ slug, name }) => ({ id: slug, name })),
];

export const permissionsFromInternal = (
  internal: Internal.Users.Permissions,
): Permissions => {
  const manageGames = manageFromInternal(internal.manage_games);
  const managePermissions = manageFromInternal(internal.manage_permissions);
  const manageGacha = manageFromInternal(internal.manage_gacha);
  const manageBets = manageBetsFromInternal(
    internal.manage_bets,
    internal.manage_bets_games,
  );
  return {
    ...(manageGames.length > 0 ? { manageGames } : {}),
    ...(managePermissions.length > 0 ? { managePermissions } : {}),
    ...(manageGacha.length > 0 ? { manageGacha } : {}),
    ...(manageBets.length > 0 ? { manageBets } : {}),
  };
};

export const fromInternal = (internal: Internal.User): [Slug, User] => [
  internal.slug,
  {
    name: internal.name,
    ...(internal.discriminator !== null
      ? { discriminator: internal.discriminator }
      : {}),
    avatar: internal.avatar_url,

    balance: internal.balance,
    betValue: internal.staked,

    created: internal.created,

    permissions: permissionsFromInternal(internal),
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

export { Slug, Summary, summaryFromInternal } from "./users/core.js";
export * as Users from "./users.js";
