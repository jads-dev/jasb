import { Stake } from "../v3";

export interface Option {
  name: string;
  image?: string;

  stakes: Record<string, Stake>;
}

export * as Options from "./options";
