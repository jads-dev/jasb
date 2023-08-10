import * as Schema from "io-ts";

import type { Gacha as Internal } from "../../internal/gacha.js";
import { Validation } from "../../util/validation.js";
import { Users } from "../users/core.js";

/**
 * An ID for a credit.
 */
interface CreditIdBrand {
  readonly CreditId: unique symbol;
}
export const Id = Validation.Id("CreditId")<CreditIdBrand>();
export type Id = Schema.TypeOf<typeof Id>;

/**
 * A credit type.
 */
export const Credit = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      reason: Schema.string,
      name: Schema.string,
    }),
    Schema.partial({
      id: Users.Slug,
      discriminator: Schema.string,
      avatar: Schema.string,
    }),
  ]),
);
export type Credit = Schema.TypeOf<typeof Credit>;

export const fromInternal = (internal: Internal.Credits.Credit): Credit => ({
  reason: internal.reason,
  name: internal.name,
  ...(internal.user_slug ? { id: internal.user_slug } : {}),
  ...(internal.discriminator ? { discriminator: internal.discriminator } : {}),
  ...(internal.avatar_url ? { avatar: internal.avatar_url } : {}),
});

/**
 * An editable credit type.
 */
export const Editable = Schema.readonly(
  Schema.intersection([
    Schema.strict({
      reason: Schema.string,
      name: Schema.string,
      version: Schema.Int,
      created: Validation.DateTime,
      modified: Validation.DateTime,
    }),
    Schema.partial({
      id: Users.Slug,
      discriminator: Schema.string,
      avatar: Schema.string,
    }),
  ]),
);
export type Editable = Schema.TypeOf<typeof Editable>;

export const EditableWithId = Schema.tuple([Id, Editable]);
export type EditableWithId = Schema.TypeOf<typeof EditableWithId>;

export const EditableById = Schema.readonlyArray(EditableWithId);
export type EditableById = Schema.TypeOf<typeof EditableById>;

export const editableFromInternal = (
  internal: Internal.Credits.Editable,
): EditableWithId => [
  internal.id,
  {
    reason: internal.reason,
    name: internal.name,
    ...(internal.user_slug ? { id: internal.user_slug } : {}),
    ...(internal.discriminator
      ? { discriminator: internal.discriminator }
      : {}),
    ...(internal.avatar_url ? { avatar: internal.avatar_url } : {}),
    version: internal.version,
    created: internal.created,
    modified: internal.modified,
  },
];

export * as Credits from "./credits.js";
