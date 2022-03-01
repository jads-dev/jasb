import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import type { Users } from "../users.js";
import { Stake, Stakes } from "./stakes.js";

interface OptionIdBrand {
  readonly OptionId: unique symbol;
}

export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, OptionIdBrand> => true,
  "OptionId",
);
export type Id = Schema.TypeOf<typeof Id>;

export interface Option {
  name: string;
  image?: string;

  stakes: Record<Users.Id, Stake>;
}

export const fromInternal = ({
  option,
  stakes,
}: Internal.Options.AndStakes): [Id, Option] => [
  option.id as Id,
  {
    name: option.name,
    ...(option.image !== null ? { image: option.image } : {}),

    stakes: Object.fromEntries(stakes.map(Stakes.fromInternal)),
  },
];

export * as Options from "./options.js";
