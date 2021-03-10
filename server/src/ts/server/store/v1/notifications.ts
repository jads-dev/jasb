import { Timestamp } from "@google-cloud/firestore";

export interface Notification {
  message: string;
  at: Timestamp;
}

export * as Notifications from "./notifications";
