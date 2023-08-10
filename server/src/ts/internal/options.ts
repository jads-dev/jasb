import { z } from "zod";

import { Stakes } from "./stakes.js";
import { Types } from "./types.js";

export const Option = z
  .object({
    slug: Types.optionSlug,
    name: z.string(),
    image: z.string().nullable(),
    stakes: z.array(Stakes.Stake),
    won: z.boolean(),
  })
  .strict();
export type Option = z.infer<typeof Option>;

export const Editable = Option.merge(
  z
    .object({
      order: Types.int,
      version: Types.nonNegativeInt,
      created: Types.zonedDateTime,
      modified: Types.zonedDateTime,
    })
    .strict(),
);
export type Editable = z.infer<typeof Editable>;

export * as Options from "./options.js";
