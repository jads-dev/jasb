import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";

/**
 * A gacha balance.
 */
export const Balance = Schema.readonly(
  Schema.strict({
    rolls: Schema.Int,
    guarantees: Schema.Int,
    scrap: Schema.Int,
  }),
);
export type Balance = Schema.TypeOf<typeof Balance>;

export const fromInternal = (internal: Internal.Balance): Balance => ({
  rolls: internal.rolls,
  guarantees: internal.guarantees,
  scrap: internal.scrap,
});

/**
 * A relative gacha value.
 */
export const Value = Schema.readonly(
  Schema.partial({
    rolls: Schema.Int,
    guarantees: Schema.Int,
    scrap: Schema.Int,
  }),
);
export type Value = Schema.TypeOf<typeof Value>;

export const valueFromInternal = (
  internal: Internal.Balances.Value,
): Value => ({
  ...(internal.rolls !== null ? { rolls: internal.rolls } : {}),
  ...(internal.guarantees !== null ? { guarantees: internal.guarantees } : {}),
  ...(internal.scrap !== null ? { scrap: internal.scrap } : {}),
});

export * as Balances from "./balances.js";
