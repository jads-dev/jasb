import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";

/**
 * An ID for a user from the perspective of the API user, this is the slug
 * internally.
 */
interface UserIdBrand {
  readonly UserId: unique symbol;
}
export const Id = Schema.brand(
  Schema.string,
  (id): id is Schema.Branded<string, UserIdBrand> => true,
  "UserId",
);
export type Id = Schema.TypeOf<typeof Id>;

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
  internal: Internal.Users.Summary,
): [Id, Summary] => [
  internal.slug as Id,
  {
    name: internal.name,
    ...(internal.discriminator !== null
      ? { discriminator: internal.discriminator }
      : {}),
    avatar: internal.avatar_url,
  },
];

export * as Users from "./id.js";
