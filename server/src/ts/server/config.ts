import * as Joda from "@js-joda/core";
import { either as Either } from "fp-ts";
import { promises as fs } from "fs";
import * as Schema from "io-ts";
import { formatValidationErrors } from "io-ts-reporters";
import { default as JSON5 } from "json5";

import {
  PlaceholderBufferSecretToken,
  PlaceholderSecretToken,
} from "../util/secret-token.js";
import { Validation } from "../util/validation.js";

export class InvalidConfigError extends Error {
  public constructor(message: string) {
    super(`Invalid configuration: ${message}.`);
  }
}

const GachaRules = Schema.strict({
  maxPity: Schema.Int,
  scrapPerRoll: Schema.Int,
  rewards: Schema.strict({
    winBetRolls: Schema.Int,
    loseBetScrap: Schema.Int,
  }),
});
export type GachaRules = Schema.TypeOf<typeof GachaRules>;

const Rules = Schema.strict({
  initialBalance: Schema.Int,
  maxStakeWhileInDebt: Schema.Int,
  notableStake: Schema.Int,
  minStake: Schema.Int,
  gacha: GachaRules,
});
export type Rules = Schema.TypeOf<typeof Rules>;

const PostgresData = Schema.partial({
  host: Schema.string,
  port: Schema.Int,
  database: Schema.string,
  user: Schema.string,
  password: Validation.SecretTokenOrPlaceholder,
  ssl: Schema.keyof({
    disable: null,
    "no-verify": null,
    require: null,
  }),
  maxListenConnections: Schema.Int,
});
export type PostgresData = Schema.TypeOf<typeof PostgresData>;

const Store = Schema.strict({
  source: PostgresData,
});
export type Store = Schema.TypeOf<typeof Store>;

const GeneralObjectStorage = Schema.intersection([
  Schema.strict({
    garbageCollection: Schema.strict({
      frequency: Validation.Duration,
      minimumAge: Validation.Duration,
    }),
    cache: Schema.strict({
      frequency: Validation.Duration,
      batchSize: Schema.Int,
    }),
  }),
  Schema.partial({
    webp: Schema.partial({
      quality: Schema.Int,
      effort: Schema.Int,
    }),
  }),
]);

export const OciObjectStorage = Schema.intersection([
  Schema.strict({
    service: Schema.literal("oci"),
    user: Schema.string,
    tenancy: Schema.string,
    fingerprint: Schema.string,
    privateKey: Validation.SecretTokenOrPlaceholder,
    region: Schema.string,

    namespace: Schema.string,
    bucket: Schema.string,
  }),
  Schema.partial({
    passphrase: Validation.SecretTokenOrPlaceholder,
  }),
  GeneralObjectStorage,
]);
export type OciObjectStorage = Schema.TypeOf<typeof OciObjectStorage>;

export const ObjectStorage = OciObjectStorage;
export type ObjectStorage = Schema.TypeOf<typeof ObjectStorage>;

const DiscordAuth = Schema.strict({
  clientId: Schema.string,
  clientSecret: Validation.SecretTokenOrPlaceholder,

  refresh: Schema.strict({
    frequency: Validation.Duration,
    expiryBuffer: Validation.Duration,
  }),

  guild: Schema.string,
});

const Algorithm = Schema.keyof({
  A128GCM: null,
  A192GCM: null,
  A256GCM: null,
  "A128CBC-HS256": null,
  "A192CBC-HS384": null,
  "A256CBC-HS512": null,
});

const ExternalService = Schema.strict({
  publicKey: Validation.JsonWebKey,
});
export type ExternalService = Schema.TypeOf<typeof ExternalService>;

const ExternalServices = Schema.strict({
  identity: Schema.string,
  tokenLifetime: Validation.Duration,

  recognised: Schema.readonly(Schema.record(Schema.string, ExternalService)),
});
export type ExternalServices = Schema.TypeOf<typeof ExternalServices>;

const Auth = Schema.intersection([
  Schema.strict({
    stateValidityDuration: Validation.Duration,
    sessions: Schema.strict({
      lifetime: Validation.Duration,
      idSize: Schema.Int,
      garbageCollectionFrequency: Validation.Duration,
    }),

    algorithm: Algorithm,
    key: Validation.BufferSecretTokenOrPlaceholder,

    discord: DiscordAuth,
  }),
  Schema.partial({
    externalServices: ExternalServices,
  }),
]);
export type Auth = Schema.TypeOf<typeof Auth>;

const DiscordNotifier = Schema.strict({
  service: Schema.literal("Discord"),
  token: Validation.SecretTokenOrPlaceholder,
  channel: Schema.string,
});
export type DiscordNotifier = Schema.TypeOf<typeof DiscordNotifier>;

const LogLevel = Schema.keyof({
  trace: null,
  debug: null,
  info: null,
  warn: null,
  error: null,
  fatal: null,
});

const Logging = Schema.strict({
  level: LogLevel,
});
export type Logging = Schema.TypeOf<typeof Logging>;

const Security = Schema.strict({
  cookies: Schema.strict({
    secret: Validation.SecretTokenOrPlaceholder,
    oldSecrets: Schema.array(Validation.SecretTokenOrPlaceholder),
    hmacAlgorithm: Schema.string,
  }),
});
export type Security = Schema.TypeOf<typeof Security>;

const Performance = Schema.strict({
  gamesCacheDuration: Validation.Duration,
  leaderboardCacheDuration: Validation.Duration,
});
export type Performance = Schema.TypeOf<typeof Performance>;

export const Server = Schema.intersection([
  Schema.strict({
    logging: Logging,
    listenOn: Schema.strict({ port: Schema.Int, address: Schema.string }),
    clientOrigin: Schema.string,
    security: Security,
    performance: Performance,

    rules: Rules,
    store: Store,
    auth: Auth,
  }),
  Schema.partial({
    notifier: DiscordNotifier,
    objectStorage: ObjectStorage,
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
  defaultPath?: string,
): Promise<Server> {
  const configPath =
    overridePath ??
    process.env[pathEnvironmentVariable] ??
    defaultPath ??
    `config.json5`;
  let current: unknown = Server.encode(builtIn);
  for (const file of configPath.split(";")) {
    const raw = await fs.readFile(file);
    const userConfig: unknown = JSON5.parse(raw.toString());
    current = deepMerge(current, userConfig);
  }
  const result = Server.decode(current);
  if (Either.isRight(result)) {
    const config = result.right;
    if (process.env["NODE_ENV"] !== "development") {
      if (config.auth.sessions.idSize < 64) {
        throw new InvalidConfigError(
          "Session ID too small, potentially vulnerable to brute force attack.",
        );
      }
      config.security.cookies.secret.inSecureEnvironment();
      config.security.cookies.oldSecrets.map((secret) => {
        secret.inSecureEnvironment();
      });
      config.auth.discord.clientSecret.inSecureEnvironment();
      config.store.source.password?.inSecureEnvironment();
      config.notifier?.token.inSecureEnvironment();
    }
    return config;
  } else {
    throw new InvalidConfigError(
      formatValidationErrors(result.left).join("\n"),
    );
  }
}

export const builtIn: Server = {
  logging: {
    level: process.env["NODE_ENV"] === "development" ? "debug" : "error",
  },
  listenOn: {
    port: 8081 as Schema.Int,
    address:
      process.env["NODE_ENV"] === "development" ? "127.0.0.1" : "0.0.0.0",
  },
  clientOrigin:
    process.env["NODE_ENV"] === "development"
      ? "http://localhost:8080"
      : "https://jasb.900000000.xyz",

  security: {
    cookies: {
      secret: new PlaceholderSecretToken(),
      oldSecrets: [],
      hmacAlgorithm: "sha256",
    },
  },

  performance: {
    gamesCacheDuration: Joda.Duration.of(1, Joda.ChronoUnit.MINUTES),
    leaderboardCacheDuration: Joda.Duration.of(1, Joda.ChronoUnit.MINUTES),
  },

  rules: {
    initialBalance: 1000 as Schema.Int,
    maxStakeWhileInDebt: 100 as Schema.Int,
    notableStake: 500 as Schema.Int,
    minStake: 25 as Schema.Int,
    gacha: {
      maxPity: 75 as Schema.Int,
      scrapPerRoll: 5 as Schema.Int,
      rewards: {
        winBetRolls: 1 as Schema.Int,
        loseBetScrap: 2 as Schema.Int,
      },
    },
  },

  store: {
    source: {
      host: "postgres",
      user: "jasb",
      password: new PlaceholderSecretToken(),
      maxListenConnections: 50 as Schema.Int,
    },
  },

  auth: {
    stateValidityDuration: Joda.Duration.of(5, Joda.ChronoUnit.MINUTES),

    sessions: {
      lifetime: Joda.Duration.of(7, Joda.ChronoUnit.DAYS),
      idSize: 64 as Schema.Int,
      garbageCollectionFrequency: Joda.Duration.of(1, Joda.ChronoUnit.HOURS),
    },

    algorithm: "A256CBC-HS512",
    key: new PlaceholderBufferSecretToken(),

    discord: {
      clientId: "CHANGE_ME",
      clientSecret: new PlaceholderSecretToken(),

      refresh: {
        frequency: Joda.Duration.of(1, Joda.ChronoUnit.HOURS),
        expiryBuffer: Joda.Duration.of(30, Joda.ChronoUnit.MINUTES),
      },

      guild: "308515582817468420",
    },
  },
};

export * as Config from "./config.js";
