import { Stake } from "./stakes";

export interface Option {
  name: string;
  image?: string;

  stakes: Record<string, Stake>;
}

export * as Options from "./options";
