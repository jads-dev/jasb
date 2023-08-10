import * as Schema from "io-ts";

import type { Internal } from "../internal.js";
import { Validation } from "../util/validation.js";
import { Games } from "./games.js";
import { Slug } from "./users/core.js";

/**
 * The permissions for a user so the UI can present the right options for a
 * user.
 */
export const UserPermissions = Schema.readonly(
  Schema.partial({
    manageGames: Schema.boolean,
    managePermissions: Schema.boolean,
    manageGacha: Schema.boolean,
    manageBets: Schema.readonlyArray(Games.Slug),
  }),
);
export type UserPermissions = Schema.TypeOf<typeof UserPermissions>;

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
      permissions: UserPermissions,
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

/**
 * When editing permissions, the details of specific game permissions that can
 * be changed.
 */
export const SpecificPermissions = Schema.readonly(
  Schema.strict({
    gameId: Games.Slug,
    gameName: Schema.string,
    manageBets: Schema.boolean,
  }),
);
export type SpecificPermissions = Schema.TypeOf<typeof SpecificPermissions>;

/**
 * When editing permissions, the details of a user's permissions that can be
 * changed, a combination of general and game-specific permissions.
 */
export const EditablePermissions = Schema.readonly(
  Schema.strict({
    manageGames: Schema.boolean,
    managePermissions: Schema.boolean,
    manageBets: Schema.boolean,
    manageGacha: Schema.boolean,
    gameSpecific: Schema.readonlyArray(SpecificPermissions),
  }),
);
export type EditablePermissions = Schema.TypeOf<typeof EditablePermissions>;

const userPermissionsFromInternal = (
  internal: Internal.Users.User,
): { permissions?: UserPermissions } => {
  const manageGames = internal.manage_games;
  const managePermissions = internal.manage_permissions;
  const manageGacha = internal.manage_gacha;
  const manageBets = internal.manage_bets;
  return manageGames ||
    managePermissions ||
    manageGacha ||
    manageBets.length > 0
    ? {
        permissions: {
          ...(manageGames ? { manageGames: true } : {}),
          ...(managePermissions ? { managePermissions: true } : {}),
          ...(manageGacha ? { manageGacha: true } : {}),
          ...(manageBets.length > 0 ? { manageBets } : {}),
        },
      }
    : {};
};

export const fromInternal = (internal: Internal.User): [Slug, User] => [
  internal.slug,
  {
    name: internal.name,
    ...(internal.discriminator !== null
      ? { discriminator: internal.discriminator }
      : {}),
    avatar: internal.avatar_url,

    balance: internal.balance as Schema.Int,
    betValue: internal.staked as Schema.Int,

    created: internal.created,

    ...userPermissionsFromInternal(internal),
  },
];

export const bankruptcyStatsFromInternal = ({
  amount_lost,
  stakes_lost,
  locked_amount_lost,
  locked_stakes_lost,
  balance_after,
}: Internal.Users.BankruptcyStats): BankruptcyStats => ({
  amountLost: amount_lost as Schema.Int,
  stakesLost: stakes_lost as Schema.Int,
  lockedAmountLost: locked_amount_lost as Schema.Int,
  lockedStakesLost: locked_stakes_lost as Schema.Int,
  balanceAfter: balance_after as Schema.Int,
});

export const specificPermissionsFromInternal = ({
  game_slug,
  game_name,
  manage_bets,
}: Internal.Users.SpecificPermissions): SpecificPermissions => ({
  gameId: game_slug,
  gameName: game_name,
  manageBets: manage_bets,
});

export const editablePermissionsFromInternal = ({
  manage_games,
  manage_permissions,
  manage_bets,
  manage_gacha,
  game_specific,
}: Internal.Users.EditablePermissions): EditablePermissions => ({
  manageGames: manage_games,
  managePermissions: manage_permissions,
  manageBets: manage_bets,
  manageGacha: manage_gacha,
  gameSpecific: game_specific.map(specificPermissionsFromInternal),
});

export { Slug, Summary, summaryFromInternal } from "./users/core.js";
export * as Users from "./users.js";
