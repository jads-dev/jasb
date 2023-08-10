import { z } from "zod";

import { Types } from "../types.js";

export const Quality = z
  .object({
    slug: Types.qualitySlug,
    name: z.string(),
  })
  .strict();
export type Quality = z.infer<typeof Quality>;

export const Detailed = z
  .object({
    slug: Types.qualitySlug,
    name: z.string(),
    description: z.string(),
  })
  .strict();
export type DetailedQuality = z.infer<typeof Detailed>;

export * as Qualities from "./qualities.js";
