export interface User {
  id: string;
  username: string;
  global_name?: string;
  discriminator?: string | null | undefined;
  avatar: string | null | undefined;
  mfa_enabled?: true;
  locale?: string;
  verified?: boolean;
  email?: string | null | undefined;
  flags?: number;
  premium_type?: number;
  public_flags?: number;
}

export interface Token {
  access_token: string;
  expires_in: number;
  refresh_token: string;
}

const mod = (n: number, d: number): number => ((n % d) + d) % d;

export const defaultAvatar = (
  id: string,
  discriminator: string | null | undefined,
): number =>
  discriminator === null || discriminator === undefined || discriminator === "0"
    ? mod(parseInt(id) >> 22, 6)
    : mod(parseInt(discriminator), 5);

export * as Discord from "./discord.js";
