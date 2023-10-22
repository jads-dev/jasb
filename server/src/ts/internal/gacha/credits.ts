import { z } from "zod";

import { Types } from "../types.js";

export const Credit = z
  .object({
    reason: z.string(),
    user_slug: Types.userSlug.nullable(),
    name: z.string(),
    discriminator: z.string().nullable(),
    avatar_url: z.string().nullable(),
  })
  .strict();
export type Credit = z.infer<typeof Credit>;

export const Editable = z
  .object({
    id: Types.creditId,
    reason: z.string(),
    user_slug: Types.userSlug.nullable(),
    name: z.string(),
    discriminator: z.string().nullable(),
    avatar_url: z.string().nullable(),
    version: Types.nonNegativeInt,
    created: Types.zonedDateTime,
    modified: Types.zonedDateTime,
  })
  .strict();
export type Editable = z.infer<typeof Editable>;

export * as Credits from "./credits.js";
