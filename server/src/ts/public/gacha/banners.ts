import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";
import { Validation } from "../../util/validation.js";

/**
 * A slug for a banner.
 */
interface BannerSlugBrand {
  readonly BannerSlug: unique symbol;
}
export const Slug = Validation.Slug("BannerSlug")<BannerSlugBrand>();
export type Slug = Schema.TypeOf<typeof Slug>;

/**
 * A banner.
 */
export const Banner = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      name: Schema.string,
      description: Schema.string,
      cover: Schema.string,
      type: Schema.string,
      colors: Schema.readonly(
        Schema.strict({
          background: Validation.HexAlphaColor,
          foreground: Validation.HexAlphaColor,
        }),
      ),
    }),
    Schema.partial({
      active: Schema.boolean,
    }),
  ]),
);
export type Banner = Schema.TypeOf<typeof Banner>;

export const WithSlug = Schema.tuple([Slug, Banner]);
export type WithSlug = Schema.TypeOf<typeof WithSlug>;

export const fromInternal = (internal: Internal.Banner): WithSlug => [
  internal.slug as Slug,
  {
    name: internal.name,
    description: internal.description,
    cover: internal.cover,
    type: internal.type,
    colors: {
      background: internal.background_color,
      foreground: internal.foreground_color,
    },
    ...(internal.active ? {} : { active: false }),
  },
];

/**
 * An editable banner.
 */
export const Editable = Schema.readonly(
  Schema.strict({
    name: Schema.string,
    description: Schema.string,
    cover: Schema.string,
    active: Schema.boolean,
    version: Schema.Int,
    type: Schema.string,
    colors: Schema.readonly(
      Schema.strict({
        background: Validation.HexAlphaColor,
        foreground: Validation.HexAlphaColor,
      }),
    ),
    created: Validation.DateTime,
    modified: Validation.DateTime,
  }),
);
export type Editable = Schema.TypeOf<typeof Editable>;

export const editableFromInternal = (
  internal: Internal.Banners.Editable,
): [Slug, Editable] => [
  internal.slug as Slug,
  {
    name: internal.name,
    description: internal.description,
    cover: internal.cover,
    active: internal.active,
    type: internal.type,
    colors: {
      background: internal.background_color,
      foreground: internal.foreground_color,
    },
    version: internal.version as Schema.Int,
    created: internal.created,
    modified: internal.modified,
  },
];

export * as Banners from "./banners.js";
