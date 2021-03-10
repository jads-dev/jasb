import { DocumentReference, Timestamp } from "@google-cloud/firestore";

export interface User {
  accessToken: string;
  refreshToken: string;

  name: string;
  discriminator: string;
  avatar?: string;

  balance: number;
  betValue: number;
  netWorth: number;

  stakesIn: DocumentReference[];

  created: Timestamp;
  admin: boolean;
}

export * as Users from "./users";
