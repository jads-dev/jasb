import * as Joda from "@js-joda/core";

export interface User {
  id: string;
  name: string;
  nickname: string | null;
  discriminator: string;
  avatar: string | null;
  avatar_cache: string | null;

  created: Joda.ZonedDateTime;
  admin: boolean;

  balance: number;
}

export interface BetStats {
  staked: number;
  net_worth: number;
}

export interface Leaderboard {
  rank: number;
}

export interface Permissions {
  moderator_for: string[];
}

export interface LoginDetail {
  session: string;
  started: Joda.ZonedDateTime;
  is_new_user: boolean;
}

export interface Summary {
  id: string;
  name: string;
  discriminator: string;
  avatar: string | null;
  avatar_cache: string | null;
}

export interface BankruptcyStats {
  amount_lost: number;
  stakes_lost: number;
  locked_amount_lost: number;
  locked_stakes_lost: number;
  balance_after: number;
}

export interface PerGamePermissions {
  game_id: string;
  game_name: string;
  manage_bets: boolean;
}

export * as Users from "./users";
