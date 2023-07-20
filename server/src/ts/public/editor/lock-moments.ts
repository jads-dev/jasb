import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Bets } from "../../public/bets.js";
import { Validation } from "../../util/validation.js";

/**
 * An ID for a lock moment from the perspective of the API user, this is the
 * slug internally.
 */
interface LockMomentIdBrand {
  readonly LockMomentId: unique symbol;
}
export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, LockMomentIdBrand> => true,
  "LockMomentId",
);
export type Id = Schema.TypeOf<typeof Id>;

/**
 * The details for a lock moment.
 */
export const LockMoment = Schema.readonly(
  Schema.strict({
    name: Schema.string,
    order: Schema.Int,
    bets: Schema.Int,
    version: Schema.Int,
    created: Validation.DateTime,
    modified: Validation.DateTime,
  }),
);
export type LockMoment = Schema.TypeOf<typeof LockMoment>;

/**
 * Lock status for a particular bet.
 */
export const BetLockStatus = Schema.readonly(
  Schema.strict({
    betId: Bets.Id,
    betName: Schema.string,
    betVersion: Schema.Int,
    locked: Schema.boolean,
  }),
);
export type BetLockStatus = Schema.TypeOf<typeof BetLockStatus>;

export const LockMomentStatuses = Schema.tuple([
  Id,
  LockMoment,
  Schema.readonlyArray(BetLockStatus),
]);
export type LockMomentStatuses = Schema.TypeOf<typeof LockMomentStatuses>;

export const GameLockStatus = Schema.readonlyArray(LockMomentStatuses);
export type GameLockStatus = Schema.TypeOf<typeof GameLockStatus>;

export const fromInternal = (
  internal: Internal.Bets.LockMoment,
): [Id, LockMoment] => [
  internal.slug as Id,
  {
    name: internal.name,
    order: internal.order as Schema.Int,
    bets: internal.bet_count as Schema.Int,

    version: internal.version as Schema.Int,
    created: internal.created,
    modified: internal.modified,
  },
];

export const betLockStatusFromInternal = (
  internal: Internal.Bets.LockStatus,
): BetLockStatus => ({
  betId: internal.bet_slug as Bets.Id,
  betName: internal.bet_name,
  betVersion: internal.bet_version as Schema.Int,
  locked: internal.locked,
});

export const lockMomentStatusesFromInternal = (
  internalLockMoment: Internal.Bets.LockMoment,
  internalLockStatuses: readonly Internal.Bets.LockStatus[],
): LockMomentStatuses => {
  const [id, lockMoment] = fromInternal(internalLockMoment);
  return [
    id,
    lockMoment,
    internalLockStatuses
      .filter((lockStatus) => lockStatus.lock_moment_slug === id)
      .map(betLockStatusFromInternal),
  ];
};

export const gameLockStatusFromInternal = (
  internalLockMoment: readonly Internal.Bets.LockMoment[],
  internalLockStatuses: readonly Internal.Bets.LockStatus[],
): GameLockStatus =>
  internalLockMoment.map((lockMoment) =>
    lockMomentStatusesFromInternal(lockMoment, internalLockStatuses),
  );

export * as LockMoments from "./lock-moments.js";
