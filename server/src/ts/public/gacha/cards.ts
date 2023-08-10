import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";
import { Validation } from "../../util/validation.js";
import { Banners } from "./banners.js";
import { Credits } from "./credits.js";
import { Qualities } from "./qualities.js";
import { Rarities } from "./rarities.js";

/**
 * An ID for a card.
 */
interface CardIdBrand {
  readonly CardId: unique symbol;
}
export const Id = Validation.Id("CardId")<CardIdBrand>();
export type Id = Schema.TypeOf<typeof Id>;

export const Shared = Schema.readonly(
  Schema.strict({
    name: Schema.string,
    description: Schema.string,
    image: Schema.string,
    rarity: Rarities.WithSlug,
  }),
);
export type Shared = Schema.TypeOf<typeof Shared>;

export const sharedFromInternal = (
  internal: Internal.Cards.Shared,
): Shared => ({
  name: internal.name,
  description: internal.description,
  image: internal.image,
  rarity: Rarities.fromInternal(internal.rarity),
});

export const Individual = Schema.readonly(
  Schema.partial({
    qualities: Qualities.BySlug,
  }),
);
export type Individual = Schema.TypeOf<typeof Individual>;

export const individualFromInternal = (
  internal: Internal.Cards.Individual,
): Individual => ({
  ...(internal.qualities.length > 0
    ? { qualities: internal.qualities.map(Qualities.fromInternal) }
    : {}),
});

export const DetailedShared = Schema.readonly(
  Schema.strict({
    retired: Schema.boolean,
    banner: Banners.WithSlug,
    credits: Schema.readonlyArray(Credits.Credit),
  }),
);
export type DetailedShared = Schema.TypeOf<typeof DetailedShared>;

export const detailedSharedFromInternal = (
  internal: Internal.Cards.DetailedShared,
): DetailedShared => ({
  retired: internal.retired,
  banner: Banners.fromInternal(internal.banner),
  credits: internal.credits.map((credit) => Credits.fromInternal(credit)),
});

export const DetailedIndividual = Schema.readonly(
  Schema.partial({
    qualities: Qualities.DetailedBySlug,
  }),
);
export type DetailedIndividual = Schema.TypeOf<typeof DetailedIndividual>;

export const detailedIndividualFromInternal = (
  internal: Internal.Cards.DetailedIndividual,
): DetailedIndividual => ({
  ...(internal.qualities.length > 0
    ? { qualities: internal.qualities.map(Qualities.detailedFromInternal) }
    : {}),
});

/**
 * A card.
 */
export const Card = Schema.readonly(Schema.intersection([Shared, Individual]));
export type Card = Schema.TypeOf<typeof Card>;

export const fromInternal = (internal: Internal.Card): [Id, Card] => [
  internal.id,
  { ...sharedFromInternal(internal), ...individualFromInternal(internal) },
];

/**
 * A detailed card.
 */
export const Detailed = Schema.readonly(
  Schema.intersection([Shared, DetailedShared, DetailedIndividual]),
);
export type Detailed = Schema.TypeOf<typeof Detailed>;

export const detailedFromInternal = (
  internal: Internal.Cards.Detailed,
): [Id, Detailed] => [
  internal.id,
  {
    ...sharedFromInternal(internal),
    ...detailedSharedFromInternal(internal),
    ...detailedIndividualFromInternal(internal),
  },
];

/**
 * Highlight information for a card.
 */
export const Highlight = Schema.readonly(
  Schema.partial({
    message: Schema.string,
  }),
);
export type Highlight = Schema.TypeOf<typeof Highlight>;

export const highlightFromInternal = (
  internal: Internal.Cards.Highlight,
): Highlight => ({
  ...(internal.message ? { message: internal.message } : {}),
});

/**
 * The card with highlight information.
 */
export const Highlighted = Schema.readonly(
  Schema.intersection([Card, Highlight]),
);
export type Highlighted = Schema.TypeOf<typeof Highlighted>;

export const highlightedFromInternal = (
  internal: Internal.Cards.Highlighted,
): [Banners.Slug, Id, Highlighted] => {
  const [id, card] = fromInternal(internal);
  return [
    internal.banner_slug,
    id,
    { ...card, ...highlightFromInternal(internal) },
  ];
};

export * as Cards from "./cards.js";
