export interface User {
  id: string;
  username: string;
  discriminator: string;
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

export * as Discord from "./discord";
