import { z } from "zod";

import { Types } from "../types.js";

export const Rarity = z
  .object({
    slug: Types.raritySlug,
    name: z.string(),
  })
  .strict();
export type Rarity = z.infer<typeof Rarity>;

export * as Rarities from "./rarities.js";
