import { Users } from "./users";

export interface Stake {
  game: string;
  bet: string;
  option: string;
  owner: string;

  made_at: string; // We get this in a JSON blob, so no automatic parsing.

  amount: number;
  message: string | null;
}

export interface WithUser {
  stake: Stake;
  user: Users.Summary;
}

export * as Stakes from "./stakes";
