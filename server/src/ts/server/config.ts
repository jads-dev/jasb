import * as Joda from "@js-joda/core";
import { either as Either } from "fp-ts";
import { promises as fs } from "fs";
import * as Schema from "io-ts";
import { PathReporter } from "io-ts/PathReporter";
import { default as JSON5 } from "json5";

import { PlaceholderSecretToken } from "../util/secret-token";
import { Validation } from "../util/validation";

export class InvalidConfigError extends Error {
  public constructor(message: string) {
    super(`Invalid configuration: ${message}.`);
  }
}

const Rules = Schema.strict({
  initialBalance: Schema.Int,
  maxBetWhileInDebt: Schema.Int,
  notableStake: Schema.Int,
});
export type Rules = Schema.TypeOf<typeof Rules>;

const Store = Schema.strict({
  projectId: Schema.string,
  garbageCollectionFrequency: Validation.Duration,
});
export type Store = Schema.TypeOf<typeof Store>;

const OciObjectUpload = Schema.strict({
  service: Schema.literal("oci"),
  configPath: Schema.string,
  namespace: Schema.string,
  bucket: Schema.string,
  baseUrl: Schema.string,
});
export type OciObjectUpload = Schema.TypeOf<typeof ObjectUpload>;

const ObjectUpload = OciObjectUpload;
export type ObjectUpload = Schema.TypeOf<typeof ObjectUpload>;

const DiscordAuth = Schema.strict({
  scopes: Schema.array(Schema.string),

  clientId: Schema.string,
  clientSecret: Validation.SecretTokenOrPlaceholder,

  guild: Schema.string,
});

const PostgresData = Schema.partial({
  user: Schema.string,
  database: Schema.string,
  password: Validation.SecretTokenOrPlaceholder,
  port: Schema.Int,
  host: Schema.string,
});
export type PostgresData = Schema.TypeOf<typeof PostgresData>;

const Auth = Schema.strict({
  sessionLifetime: Validation.Duration,
  sessionIdSize: Schema.Int,

  discord: DiscordAuth,
});
export type Auth = Schema.TypeOf<typeof Auth>;

const DiscordNotifier = Schema.strict({
  service: Schema.literal("Discord"),
  token: Validation.SecretTokenOrPlaceholder,
  channel: Schema.string,
});
export type DiscordNotifier = Schema.TypeOf<typeof DiscordNotifier>;

const Server = Schema.intersection([
  Schema.strict({
    logLevel: Schema.string,
    listenOn: Schema.strict({ port: Schema.Int, address: Schema.string }),
    clientOrigin: Schema.string,

    rules: Rules,
    store: Store,
    data: PostgresData,
    auth: Auth,
  }),
  Schema.partial({
    notifier: DiscordNotifier,
    objectUploader: ObjectUpload,
  }),
]);
export type Server = Schema.TypeOf<typeof Server>;

export const pathEnvironmentVariable = "JASB_CONFIG_PATH";

const isObject = (value: unknown): value is Record<string, unknown> =>
  value !== undefined && typeof value === "object" && !Array.isArray(value);

function deepMerge(a: unknown, b: unknown): unknown {
  if (isObject(a) && isObject(b)) {
    const result: Record<string, unknown> = { ...a };
    for (const key in b) {
      if (Object.prototype.hasOwnProperty.call(b, key)) {
        result[key] = deepMerge(a[key], b[key]);
      }
    }
    return result;
  } else if (b === undefined) {
    return a;
  } else {
    return b;
  }
}

export async function load(
  overridePath?: string,
  defaultPath?: string
): Promise<Server> {
  const configPath =
    overridePath ??
    process.env[pathEnvironmentVariable] ??
    defaultPath ??
    `config.json5`;
  let current: unknown = Server.encode(builtIn);
  for (const file of configPath.split(";")) {
    const raw = await fs.readFile(file);
    const userConfig = JSON5.parse(raw.toString());
    current = deepMerge(current, userConfig);
  }
  const result = Server.decode(current);
  if (Either.isRight(result)) {
    const config = result.right;
    if (process.env.NODE_ENV !== "development") {
      if (config.auth.sessionIdSize < 64) {
        throw new InvalidConfigError(
          "Session ID too small, potentially vulnerable to brute force attack."
        );
      }
      config.auth.discord.clientSecret.inSecureEnvironment();
      config.data.password?.inSecureEnvironment();
      config.notifier?.token?.inSecureEnvironment();
    }
    return config;
  } else {
    throw new InvalidConfigError(PathReporter.report(result).join("\n"));
  }
}

export const builtIn: Server = {
  logLevel: process.env.NODE_ENV === "development" ? "debug" : "error",
  listenOn: {
    port: 8081 as Schema.Int,
    address: process.env.NODE_ENV === "development" ? "127.0.0.1" : "0.0.0.0",
  },
  clientOrigin:
    process.env.NODE_ENV === "development"
      ? "http://localhost:8080"
      : "https://jasb.900000000.xyz",

  rules: {
    initialBalance: 1000 as Schema.Int,
    maxBetWhileInDebt: 100 as Schema.Int,
    notableStake: 500 as Schema.Int,
  },

  store: {
    projectId: "jasb",
    garbageCollectionFrequency: Joda.Duration.of(1, Joda.ChronoUnit.HOURS),
  },

  data: {
    host: "postgres",
    user: "jasb",
    password: new PlaceholderSecretToken(),
  },

  auth: {
    sessionLifetime: Joda.Duration.of(7, Joda.ChronoUnit.DAYS),
    sessionIdSize: 64 as Schema.Int,

    discord: {
      scopes: ["identify", "guilds"],

      clientId: "CHANGE_ME",
      clientSecret: new PlaceholderSecretToken(),

      guild: "308515582817468420",
    },
  },
};

export * as Config from "./config";
