import { z } from "zod";

import { Types } from "../types.js";

export const Banner = z
  .object({
    slug: Types.bannerSlug,
    name: z.string(),
    description: z.string(),
    cover: z.string(),
    active: z.boolean(),
    type: z.string(),
    background_color: Types.color,
    foreground_color: Types.color,
  })
  .strict();
export type Banner = z.infer<typeof Banner>;

export const Editable = z
  .object({
    slug: Types.bannerSlug,
    name: z.string(),
    description: z.string(),
    cover: z.string(),
    active: z.boolean(),
    type: z.string(),
    background_color: Types.color,
    foreground_color: Types.color,
    version: Types.nonNegativeInt,
    created: Types.zonedDateTime,
    modified: Types.zonedDateTime,
  })
  .strict();
export type Editable = z.infer<typeof Editable>;

export * as Banners from "./banners.js";
