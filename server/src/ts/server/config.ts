import { Duration } from "luxon";

export type Server = {
  logLevel: string;
  listenOn: number;
  clientOrigin: string;

  rules: Rules;

  store: Store;

  auth: Auth;
};

export interface Rules {
  initialBalance: number;
}

export interface Store {
  projectId: string;
}

export interface Auth {
  tokenLifetime: Duration;

  discord: Discord;

  privateKey: JsonWebKey & { kid: string };
}

export interface Discord {
  scopes: string[];

  clientId: string;
  clientSecret: string;
}

export const builtIn: Server = {
  logLevel: process.env.NODE_ENV === "development" ? "debug" : "error",
  listenOn: 8081,
  clientOrigin:
    process.env.NODE_ENV === "development"
      ? "http://localhost:8080"
      : "https://jasb.900000000.xyz",

  rules: {
    initialBalance: 1000,
  },

  store: {
    projectId:
      process.env.NODE_ENV === "development" ? "development" : "production",
  },

  auth: {
    tokenLifetime: Duration.fromObject({ weeks: 1 }),

    discord: {
      scopes: ["identify", "guilds"],

      clientId: "replaceMe",
      clientSecret: "replaceMe",
    },

    privateKey: {
      kty: "replaceMe",
      d: "replaceMe",
      use: "replaceMe",
      crv: "replaceMe",
      kid: "replaceMe",
      x: "replaceMe",
      y: "replaceMe",
      alg: "replaceMe",
    },
  },
};

export * as Config from "./config";
