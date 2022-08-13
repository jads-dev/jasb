import { z } from "zod";

import { Stakes } from "./stakes.js";
import { zonedDateTime } from "./types.js";

export const Option = z
  .object({
    game: z.string(),
    bet: z.string(),
    id: z.string(),

    name: z.string(),
    image: z.string().nullable(),

    order: z.number().int(),

    won: z.boolean(),

    version: z.number().int().nonnegative(),
    created: zonedDateTime,
    modified: zonedDateTime,
  })
  .strict();
export type Option = z.infer<typeof Option>;

export const AndStakes = z
  .object({
    option: Option,
    stakes: z.array(Stakes.WithUser),
  })
  .strict();
export type AndStakes = z.infer<typeof AndStakes>;

export * as Options from "./options.js";
