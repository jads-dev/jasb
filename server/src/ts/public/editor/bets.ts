import * as Schema from "io-ts";

import type { Internal } from "../../internal.js";
import { Validation } from "../../util/validation.js";
import { Bets } from "../bets.js";
import { Options } from "../bets/options.js";
import { Stake, Stakes } from "../bets/stakes.js";
import { Users } from "../users.js";
import { LockMoments } from "./lock-moments.js";

/**
 * The details for editing an option.
 */
export const EditableOption = Schema.intersection([
  Schema.readonly(
    Schema.strict({
      id: Options.Slug,
      name: Schema.string,
      order: Schema.Int,
      stakes: Schema.readonlyArray(Schema.tuple([Users.Slug, Stake])),
      version: Schema.Int,
      created: Validation.DateTime,
      modified: Validation.DateTime,
    }),
  ),
  Schema.partial({
    image: Schema.string,
    won: Schema.boolean,
  }),
]);
export type EditableOption = Schema.TypeOf<typeof EditableOption>;

export const Progress = Schema.keyof({
  Voting: null,
  Locked: null,
  Complete: null,
  Cancelled: null,
});
export type Progress = Schema.TypeOf<typeof Progress>;

/**
 * The details for editing a bet.
 */
export const EditableBet = Schema.intersection([
  Schema.readonly(
    Schema.strict({
      id: Bets.Slug,
      name: Schema.string,
      description: Schema.string,
      spoiler: Schema.boolean,
      lockMoment: LockMoments.Slug,
      progress: Progress,
      options: Schema.readonlyArray(EditableOption),
      author: Schema.tuple([Users.Slug, Users.Summary]),
      version: Schema.Int,
      created: Validation.DateTime,
      modified: Validation.DateTime,
    }),
  ),
  Schema.partial({
    resolved: Validation.DateTime,
    cancelledReason: Schema.string,
  }),
]);
export type EditableBet = Schema.TypeOf<typeof EditableBet>;

const editableOptionFromInternal = (
  internal: Internal.Options.Editable,
): EditableOption => ({
  id: internal.slug,
  name: internal.name,
  ...(internal.image !== null ? { image: internal.image } : {}),
  order: internal.order,
  ...(internal.won ? { won: true } : {}),
  stakes: internal.stakes.map(Stakes.fromInternal),
  version: internal.version,
  created: internal.created,
  modified: internal.modified,
});

export const fromInternal = (
  internal: Internal.Bets.Editable,
): EditableBet => ({
  id: internal.slug,
  name: internal.name,
  description: internal.description,
  spoiler: internal.spoiler,
  lockMoment: internal.lock_moment_slug,
  progress: internal.progress,
  ...(internal.resolved !== null ? { resolved: internal.resolved } : {}),
  ...(internal.cancelled_reason !== null
    ? { cancelledReason: internal.cancelled_reason }
    : {}),
  options: internal.options.map(editableOptionFromInternal),
  author: [
    internal.author_slug,
    {
      name: internal.author_name,
      ...(internal.author_discriminator !== null
        ? { discriminator: internal.author_discriminator }
        : {}),
      avatar: internal.author_avatar_url,
    },
  ],
  version: internal.version,
  created: internal.created,
  modified: internal.modified,
});

export * as Bets from "./bets.js";
