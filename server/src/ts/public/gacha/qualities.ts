import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";
import { Validation } from "../../util/validation.js";

/**
 * A slug for qualities.
 */
interface QualitySlugBrand {
  readonly QualitySlug: unique symbol;
}
export const Slug = Validation.Slug("QualitySlug")<QualitySlugBrand>();
export type Slug = Schema.TypeOf<typeof Slug>;

export const Quality = Schema.readonly(Schema.strict({ name: Schema.string }));
export type Quality = Schema.TypeOf<typeof Quality>;

export const WithSlug = Schema.tuple([Slug, Quality]);
export type WithSlug = Schema.TypeOf<typeof WithSlug>;

export const BySlug = Schema.readonlyArray(WithSlug);
export type BySlug = Schema.TypeOf<typeof BySlug>;

export const fromInternal = (internal: Internal.Quality): WithSlug => [
  internal.slug,
  { name: internal.name },
];

export const Detailed = Schema.readonly(
  Schema.strict({ name: Schema.string, description: Schema.string }),
);
export type Detailed = Schema.TypeOf<typeof Detailed>;

export const DetailedWithSlug = Schema.tuple([Slug, Detailed]);
export type DetailedWithSlug = Schema.TypeOf<typeof DetailedWithSlug>;

export const DetailedBySlug = Schema.readonlyArray(DetailedWithSlug);
export type DetailedBySlug = Schema.TypeOf<typeof DetailedBySlug>;

export const detailedFromInternal = (
  internal: Internal.Qualities.DetailedQuality,
): DetailedWithSlug => [
  internal.slug,
  { name: internal.name, description: internal.description },
];

export * as Qualities from "./qualities.js";
