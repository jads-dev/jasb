import * as Schema from "io-ts";

import { Qualities } from "./qualities.js";
import { Rarities } from "./rarities.js";

export const Context = Schema.readonly(
  Schema.strict({
    rarities: Schema.readonlyArray(
      Schema.tuple([Rarities.Slug, Rarities.Rarity]),
    ),
    qualities: Schema.readonlyArray(
      Schema.tuple([Qualities.Slug, Qualities.Quality]),
    ),
  }),
);
export type Context = Schema.TypeOf<typeof Context>;
