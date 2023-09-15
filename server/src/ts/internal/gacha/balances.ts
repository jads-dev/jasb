import { z } from "zod";

import { Types } from "../types.js";

export const Balance = z
  .object({
    rolls: Types.nonNegativeInt,
    pity: Types.nonNegativeInt,
    guarantees: Types.nonNegativeInt,
    scrap: Types.nonNegativeInt,
  })
  .strict();
export type Balance = z.infer<typeof Balance>;

export const Value = z
  .object({
    rolls: Types.int.nullable(),
    guarantees: Types.int.nullable(),
    scrap: Types.int.nullable(),
  })
  .strict();
export type Value = z.infer<typeof Value>;

export * as Balances from "./balances.js";
