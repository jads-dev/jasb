import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Validation } from "../../util/validation.js";
import { Users } from "../users/core.js";
import { Stake, Stakes } from "./stakes.js";

/**
 * A slug for an option.
 */
interface OptionSlugBrand {
  readonly OptionSlug: unique symbol;
}
export const Slug = Validation.Slug("OptionSlug")<OptionSlugBrand>();
export type Slug = Schema.TypeOf<typeof Slug>;

/**
 * An option that can win the bet, for users to place stakes against.
 */
export const Option = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      name: Schema.string,
      stakes: Schema.readonlyArray(Schema.tuple([Users.Slug, Stake])),
    }),
    Schema.partial({
      image: Schema.string,
    }),
  ]),
);
export type Option = Schema.TypeOf<typeof Option>;

export const fromInternal = (
  internal: Internal.Options.Option,
): [Slug, Option] => [
  internal.slug,
  {
    name: internal.name,
    ...(internal.image !== null ? { image: internal.image } : {}),
    stakes: internal.stakes.map(Stakes.fromInternal),
  },
];

export * as Options from "./options.js";
