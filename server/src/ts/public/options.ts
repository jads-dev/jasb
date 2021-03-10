import { Internal } from "../internal";
import { Objects } from "../util/objects";
import { Stake, Stakes } from "./stakes";
import { Users } from "./users";

export type Id = string;

export interface Option {
  name: string;
  image?: string;

  stakes: Record<Users.Id, Stake>;
}

export const toInternal = (option: Option): Internal.Option => ({
  name: option.name,
  ...(option.image !== undefined ? { image: option.image } : {}),

  stakes: {},
});

export const fromInternal = (internal: Internal.Option): Option => ({
  name: internal.name,
  image: internal.image,

  stakes: Objects.mapValues(internal.stakes, Stakes.fromInternal),
});

export * as Options from "./options";
