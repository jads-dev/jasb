import { Timestamp } from "@google-cloud/firestore";

export interface User {
  accessToken: string;
  refreshToken: string;

  name: string;
  discriminator: string;
  avatar?: string;

  balance: number;
  betValue: number;
  netWorth: number;

  created: Timestamp;

  admin: boolean;
  mod?: string[];
}

export * as Users from "./users";
