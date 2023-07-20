import { z } from "zod";

import { Stakes } from "./stakes.js";
import { Types } from "./types.js";

export const Option = z
  .object({
    slug: z.string(),
    name: z.string(),
    image: z.string().nullable(),
    stakes: z.array(Stakes.Stake),
    won: z.boolean(),
  })
  .strict();
export type Option = z.infer<typeof Option>;

export const EditableOption = Option.merge(
  z
    .object({
      order: z.number().int(),
      version: z.number().int().nonnegative(),
      created: Types.zonedDateTime,
      modified: Types.zonedDateTime,
    })
    .strict(),
);
export type EditableOption = z.infer<typeof EditableOption>;

export * as Options from "./options.js";
