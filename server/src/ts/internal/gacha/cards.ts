import { z } from "zod";

import { Types } from "../types.js";
import { Banner } from "./banners.js";
import { Credits } from "./credits.js";
import { Qualities, Quality } from "./qualities.js";
import { Rarity } from "./rarities.js";

export const Layout = z.enum(["Normal", "FullImage", "LandscapeFullImage"]);
export type Layout = z.infer<typeof Layout>;

/**
 * The parts of a card that are specific to that instance of a card, as opposed
 * to being a part of the card type.
 */
export const Individual = z.object({
  id: Types.cardId,
  qualities: z.array(Quality),
});
export type Individual = z.infer<typeof Individual>;

/**
 * The parts of a card that are shared between all instances of the same type,
 * as opposed to those that are specific to that instance of the card.
 */
export const Shared = z.object({
  name: z.string(),
  description: z.string(),
  image: z.string(),
  rarity: Rarity,
  layout: Layout,
});
export type Shared = z.infer<typeof Shared>;

/**
 * The parts of a card that are only required when viewing more detail about it,
 * unique to a card.
 */
export const DetailedIndividual = z.object({
  qualities: z.array(Qualities.Detailed),
});
export type DetailedIndividual = z.infer<typeof DetailedIndividual>;

/**
 * The parts of a card that are only required when viewing more detail about it,
 * shared between all instances of a card type.
 */
export const DetailedShared = z.object({
  retired: z.boolean(),
  credits: z.array(Credits.Credit),
  banner: Banner,
});
export type DetailedShared = z.infer<typeof DetailedShared>;

/**
 * A complete card.
 */
export const Card = Individual.merge(Shared).strict();
export type Card = z.infer<typeof Card>;

/**
 * A card with detailed information.
 */
export const Detailed = Individual.merge(Shared)
  .merge(DetailedIndividual)
  .merge(DetailedShared)
  .strict();
export type Detailed = z.infer<typeof Detailed>;

/**
 * A highlight is extra user information added to a card to display it with
 * more prominence than most.
 */
export const Highlight = z.object({
  message: z.string().nullable(),
});
export type Highlight = z.infer<typeof Highlight>;

/**
 * The card with highlight information.
 */
export const Highlighted = Individual.merge(Shared)
  .merge(Highlight)
  .merge(z.object({ banner_slug: Types.bannerSlug }))
  .strict();
export type Highlighted = z.infer<typeof Highlighted>;

export * as Cards from "./cards.js";
