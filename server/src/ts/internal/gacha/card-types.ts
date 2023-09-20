import { z } from "zod";

import { Types } from "../types.js";
import { Cards } from "./cards.js";
import { Credits } from "./credits.js";
import { Rarity } from "./rarities.js";

export const Editable = z
  .object({
    id: Types.cardTypeId,
    name: z.string(),
    description: z.string(),
    image: z.string(),
    layout: Cards.Layout,
    rarity_slug: Types.raritySlug,
    rarity_name: z.string(),
    retired: z.boolean(),
    credits: z.array(Credits.Editable),
    version: Types.nonNegativeInt,
    created: Types.zonedDateTime,
    modified: Types.zonedDateTime,
  })
  .strict();
export type Editable = z.infer<typeof Editable>;

const Base = z.object({
  id: Types.cardTypeId,
});

/**
 * A card type.
 */
export const CardType = Base.merge(Cards.Shared).strict();
export type CardType = z.infer<typeof CardType>;

/**
 * A rarity with optional card type.
 */
export const OptionalForRarity = z.union([
  z
    .object({
      id: z.null(),
      name: z.null(),
      description: z.null(),
      image: z.null(),
      layout: z.null(),
      rarity: Rarity,
    })
    .strict(),
  CardType,
]);
export type OptionalForRarity = z.infer<typeof OptionalForRarity>;

/**
 * A card type with detailed information.
 */
export const Detailed = Base.merge(Cards.Shared)
  .merge(Cards.DetailedShared)
  .strict();
export type Detailed = z.infer<typeof Detailed>;

/**
 * The card type with instances of that card type. This avoids repeating the
 * shared information.
 */
export const WithCards = Base.merge(Cards.Shared)
  .merge(
    z.object({
      cards: z.array(Cards.Individual.strict()),
    }),
  )
  .strict();
export type WithCards = z.infer<typeof WithCards>;

export * as CardTypes from "./card-types.js";
