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
  rolls: internal.rolls as Schema.Int,
  guarantees: internal.guarantees as Schema.Int,
  scrap: internal.scrap as Schema.Int,
});

export * as Balances from "./balances.js";
