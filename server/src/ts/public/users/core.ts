import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Validation } from "../../util/validation.js";

/**
 * The slug for a user.
 */
interface UserSlugBrand {
  readonly UserSlug: unique symbol;
}
export const Slug = Validation.Slug("UserSlug")<UserSlugBrand>();
export type Slug = Schema.TypeOf<typeof Slug>;

/**
 * A summary of a user for displaying information about them.
 */
export const Summary = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      name: Schema.string,
      avatar: Schema.string,
    }),
    Schema.partial({
      discriminator: Schema.string,
    }),
  ]),
);
export type Summary = Schema.TypeOf<typeof Summary>;

export const summaryFromInternal = (
  internal: Internal.Users.Summary | Internal.Users.User,
): [Slug, Summary] => [
  internal.slug as Slug,
  {
    name: internal.name,
    ...(internal.discriminator !== null
      ? { discriminator: internal.discriminator }
      : {}),
    avatar: internal.avatar_url,
  },
];

export * as Users from "./core.js";
