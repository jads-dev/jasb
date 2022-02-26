export interface CacheDetails {
  discriminator: string;
  id: string;
  avatar: string | null;
}

export interface SharedAvatarKey extends Record<string, string> {
  discriminator: string;
}

export interface UserAvatarKey extends Record<string, string> {
  user: string;
  avatar: string;
}

export type Key = SharedAvatarKey | UserAvatarKey;

export * as AvatarCache from "./avatar-cache.js";
