import { z } from "zod";

// The case where there is a custom user avatar with a hash.
export const UserMeta = z
  .object({
    id: z.number().int(),
    discord_user: z.string(),
    hash: z.string(),
    default_index: z.null(),
    url: z.string().url(),
    cached: z.boolean(),
  })
  .strict();
export type UserMeta = z.infer<typeof UserMeta>;

// The case where there is a default avatar with an index.
export const DefaultMeta = z
  .object({
    id: z.number().int(),
    discord_user: z.null(),
    hash: z.null(),
    default_index: z.number().int(),
    url: z.string().url(),
    cached: z.boolean(),
  })
  .strict();
export type DefaultMeta = z.infer<typeof DefaultMeta>;

export const Meta = z.union([UserMeta, DefaultMeta]);
export type Meta = z.infer<typeof Meta>;

export * as AvatarCache from "./avatar-cache.js";
