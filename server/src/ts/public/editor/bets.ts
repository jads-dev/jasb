import type { Internal } from "../../internal";
import { Stake, Stakes } from "../bets";
import type { Options } from "../bets/options";
import type { Users } from "../users";
import * as Joda from "@js-joda/core";

export interface EditableOption {
  id: Options.Id;
  name: string;
  image?: string;
  order: number;
  won?: true;

  stakes: Record<Users.Id, Stake>;

  version: number;
  created: string;
  modified: string;
}

export interface EditableBet {
  name: string;
  description: string;
  spoiler: boolean;
  locksWhen: string;
  progress: Internal.Bets.Progress;
  options: EditableOption[];
  resolved?: string;
  cancelledReason?: string;

  by: Users.Id;
  author: Users.Summary;
  version: number;
  created: string;
  modified: string;
}

const optionFromInternal = (
  { option, stakes }: Internal.Options.AndStakes,
  index: number
): EditableOption => ({
  id: option.id as Options.Id,
  name: option.name,
  ...(option.image !== null ? { image: option.image } : {}),
  order: index,
  ...(option.won ? { won: true } : {}),

  stakes: Object.fromEntries(stakes.map(Stakes.fromInternal)),

  version: option.version,
  created: Joda.ZonedDateTime.parse(option.created).toJSON(),
  modified: Joda.ZonedDateTime.parse(option.modified).toJSON(),
});

export const fromInternal = (
  internal: Internal.Bet & Internal.Bets.Options & Internal.Bets.Author
): EditableBet => ({
  name: internal.name,
  description: internal.description,
  spoiler: internal.spoiler,
  locksWhen: internal.locks_when,
  progress: internal.progress,
  options: internal.options.map(optionFromInternal),
  ...(internal.resolved !== null
    ? { resolved: internal.resolved.toJSON() }
    : {}),
  ...(internal.cancelled_reason !== null
    ? { cancelledReason: internal.cancelled_reason }
    : {}),

  by: internal.by as Users.Id,
  author: {
    name: internal.author_name,
    ...(internal.author_avatar !== null
      ? { avatar: internal.author_avatar }
      : {}),
    discriminator: internal.author_discriminator,
  },
  version: internal.version,
  created: internal.created.toJSON(),
  modified: internal.modified.toJSON(),
});

export * as Bets from "./bets";
