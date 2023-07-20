import { z } from "zod";

export const CacheDetails = z
  .object({
    discriminator: z.string().nullable(),
    id: z.string(),
    avatar: z.string().nullable(),
  })
  .strict();
export type CacheDetails = z.infer<typeof CacheDetails>;

export const SharedAvatarKey = z
  .object({
    discriminator: z.string(),
  })
  .strict();
export type SharedAvatarKey = z.infer<typeof SharedAvatarKey>;

export const UserAvatarKey = z
  .object({
    user: z.string(),
    avatar: z.string(),
  })
  .strict();
export type UserAvatarKey = z.infer<typeof UserAvatarKey>;

export const Key = z.union([SharedAvatarKey, UserAvatarKey]);
export type Key = z.infer<typeof Key>;

export const Url = z
  .object({
    url: z.string().url(),
  })
  .strict();
export type Url = z.infer<typeof Url>;

export * as AvatarCache from "./avatar-cache.js";
