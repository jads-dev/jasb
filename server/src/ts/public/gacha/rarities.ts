import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";
import { Validation } from "../../util/validation.js";

/**
 * An slug for rarities.
 */
interface RaritySlugBrand {
  readonly RaritySlug: unique symbol;
}
export const Slug = Validation.Slug("RaritySlug")<RaritySlugBrand>();
export type Slug = Schema.TypeOf<typeof Slug>;

export const Rarity = Schema.readonly(Schema.strict({ name: Schema.string }));
export type Rarity = Schema.TypeOf<typeof Rarity>;

export const WithSlug = Schema.tuple([Slug, Rarity]);
export type WithSlug = Schema.TypeOf<typeof WithSlug>;

export const fromInternal = (internal: Internal.Rarity): WithSlug => [
  internal.slug,
  { name: internal.name },
];

export * as Rarities from "./rarities.js";
