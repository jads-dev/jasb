import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";
import { Validation } from "../../util/validation.js";
import { Banners } from "./banners.js";
import { Cards } from "./cards.js";
import { Credits } from "./credits.js";
import { Rarities } from "./rarities.js";

/**
 * An ID for a card type.
 */
interface CardTypeIdBrand {
  readonly CardTypeId: unique symbol;
}
export const Id = Validation.Id("CardTypeId")<CardTypeIdBrand>();
export type Id = Schema.TypeOf<typeof Id>;

/**
 * A card type.
 */
export const CardType = Schema.readonly(Cards.Shared);
export type CardType = Schema.TypeOf<typeof CardType>;

export const WithId = Schema.tuple([Id, CardType]);
export type WithId = Schema.TypeOf<typeof WithId>;

export const fromInternal = (internal: Internal.CardTypes.CardType): WithId => [
  internal.id,
  {
    name: internal.name,
    description: internal.description,
    image: internal.image,
    rarity: Rarities.fromInternal(internal.rarity),
    layout: internal.layout,
    ...(internal.retired ? { retired: internal.retired } : {}),
  },
];

export const optionalByRarity = (
  internal: Internal.CardTypes.OptionalForRarity,
): WithId | Rarities.WithSlug =>
  internal.id !== null
    ? fromInternal(internal)
    : Rarities.fromInternal(internal.rarity);

/**
 * A detailed card type.
 */
export const Detailed = Schema.readonly(
  Schema.intersection([
    CardType,
    Schema.strict({
      banner: Banners.WithSlug,
      credits: Schema.readonlyArray(Credits.Credit),
    }),
  ]),
);
export type Detailed = Schema.TypeOf<typeof Detailed>;

export const detailedFromInternal = (
  internal: Internal.CardTypes.Detailed,
): [Id, Detailed] => {
  const [id, cardType] = fromInternal(internal);
  return [
    id,
    {
      ...cardType,
      banner: Banners.fromInternal(internal.banner),
      credits: internal.credits.map(Credits.fromInternal),
    },
  ];
};

/**
 * An editable card type.
 */
export const EditableCardType = Schema.readonly(
  Schema.strict({
    name: Schema.string,
    description: Schema.string,
    image: Schema.string,
    retired: Schema.boolean,
    rarity: Rarities.Slug,
    layout: Cards.Layout,
    credits: Credits.EditableById,
    version: Schema.Int,
    created: Validation.DateTime,
    modified: Validation.DateTime,
  }),
);
export type EditableCardType = Schema.TypeOf<typeof EditableCardType>;

export const editableFromInternal = (
  internal: Internal.CardTypes.Editable,
): [Id, EditableCardType] => [
  internal.id,
  {
    name: internal.name,
    description: internal.description,
    image: internal.image,
    retired: internal.retired,
    rarity: internal.rarity_slug,
    layout: internal.layout,
    credits: internal.credits.map(Credits.editableFromInternal),
    version: internal.version,
    created: internal.created,
    modified: internal.modified,
  },
];

export const WithCards = Schema.readonly(
  Schema.intersection([
    CardType,
    Schema.strict({
      cards: Schema.readonlyArray(Schema.tuple([Cards.Id, Cards.Individual])),
    }),
  ]),
);
export type WithCards = Schema.TypeOf<typeof WithCards>;

export const withCardsFromInternal = (
  internal: Internal.CardTypes.WithCards,
): [Id, WithCards] => {
  const [id, cardType] = fromInternal(internal);
  return [
    id,
    {
      ...cardType,
      cards: internal.cards.map((card) => [
        card.id,
        Cards.individualFromInternal(card),
      ]),
    },
  ];
};

export * as CardTypes from "./card-types.js";
