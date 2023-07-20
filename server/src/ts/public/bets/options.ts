import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Users } from "../users/id.js";
import { Stake, Stakes } from "./stakes.js";

/**
 * An ID for an option from the perspective of the API user, this is the slug
 * internally.
 */
interface OptionIdBrand {
  readonly OptionId: unique symbol;
}
export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, OptionIdBrand> => true,
  "OptionId",
);
export type Id = Schema.TypeOf<typeof Id>;

/**
 * An option that can win the bet, for users to place stakes against.
 */
export const Option = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      name: Schema.string,
      stakes: Schema.readonlyArray(Schema.tuple([Users.Id, Stake])),
    }),
    Schema.partial({
      image: Schema.string,
    }),
  ]),
);
export type Option = Schema.TypeOf<typeof Option>;

export const fromInternal = (
  internal: Internal.Options.Option,
): [Id, Option] => [
  internal.slug as Id,
  {
    name: internal.name,
    ...(internal.image !== null ? { image: internal.image } : {}),
    stakes: internal.stakes.map(Stakes.fromInternal),
  },
];

export * as Options from "./options.js";
