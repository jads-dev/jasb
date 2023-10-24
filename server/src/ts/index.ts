import * as Joda from "@js-joda/core";
import { StatusCodes } from "http-status-codes";
import { default as KeyGrip } from "keygrip";
import { default as Koa } from "koa";
import { default as EasyWS } from "koa-easy-ws";

import { Objects } from "./data/objects.js";
import { Store } from "./data/store.js";
import { Server } from "./server.js";
import { Auth } from "./server/auth.js";
import { Background } from "./server/background.js";
import { Config } from "./server/config.js";
import * as Errors from "./server/errors.js";
import { WebError } from "./server/errors.js";
import { ExitCodes } from "./server/exit-codes.js";
import { ExternalNotifier } from "./server/external-notifier.js";
import { NullNotifier } from "./server/external-notifier/null.js";
import { Logging } from "./server/logging.js";
import { Routes } from "./server/routes.js";
import { WebSockets } from "./server/web-sockets.js";
import { Promises } from "./util/promises.js";

const init = (config: Config.Server): Promise<Logging.Logger> =>
  Promise.resolve(Logging.init(config.logging));

const proxyPlaceholder: unique symbol = Symbol();
type ProxyPlaceholder = typeof proxyPlaceholder;
class ServerLoader implements Server.State {
  readonly config: Config.Server;
  readonly logger: Logging.Logger;
  readonly ready: Promise<void>;
  store: Store;
  auth: Auth;
  webSockets: WebSockets;
  externalNotifier: ExternalNotifier.Notifier;
  objectStorage: Objects.Storage | null;

  async #retry(
    system: string,
    load: () => Promise<void>,
    maxAttempts = 3,
    attemptDelay: Joda.Duration = Joda.Duration.ofSeconds(5),
  ): Promise<void> {
    let lastError: unknown;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await load();
        return;
      } catch (error: unknown) {
        lastError = error;
        this.logger.warn(
          { err: error },
          `Failed to load ${system}, attempt ${attempt} of ${maxAttempts}.`,
        );
      }
      await Promises.wait(attemptDelay);
    }
    throw lastError;
  }

  #placeholder<System>(systemName: string): System {
    const unavailable = () => {
      throw new WebError(
        StatusCodes.SERVICE_UNAVAILABLE,
        `${systemName} not yet loaded.`,
      );
    };
    return new Proxy(
      {},
      {
        get: unavailable,
        set: unavailable,
      },
    ) as System;
  }

  constructor(config: Config.Server, logger: Logging.Logger) {
    this.config = config;
    this.logger = logger;

    const loading: Promise<void>[] = [];
    const system = <Key extends keyof this, System extends this[Key]>(
      systemName: string,
      field: Key,
      init: () => Promise<System>,
      placeholder: System | ProxyPlaceholder = proxyPlaceholder,
      maxAttempts = 3,
      attemptDelay: Joda.Duration = Joda.Duration.ofSeconds(5),
    ): System => {
      loading.push(
        this.#retry(
          systemName,
          () =>
            init().then((system) => {
              this.logger.info(`Loaded ${systemName}.`);
              this[field] = system;
            }),
          maxAttempts,
          attemptDelay,
        ),
      );
      return placeholder !== proxyPlaceholder
        ? placeholder
        : this.#placeholder<System>(systemName);
    };
    this.store = system("Store", "store", async () => Store.init(this.config));
    this.auth = system("Authentication", "auth", async () =>
      Auth.init(this.config.auth),
    );
    this.webSockets = system("WebSocket Manager", "webSockets", async () =>
      WebSockets.init(this.config),
    );
    this.externalNotifier = system(
      "External Notifier",
      "externalNotifier",
      async () => ExternalNotifier.init(this.logger, this.config),
      new NullNotifier(),
    );
    this.objectStorage = system(
      "Object Storage",
      "objectStorage",
      async () => Objects.storage(this.logger, this.config.objectStorage),
      null,
    );
    this.ready = (async () => {
      await Promise.all(loading);
    })();
  }
}

const load = async (
  config: Config.Server,
  logger: Logging.Logger,
): Promise<Server.State> => Promise.resolve(new ServerLoader(config, logger));

const unload = async (server: Server.State): Promise<void> => {
  await server.store.unload();
};

const start = async (server: Server.State): Promise<void> => {
  const app = new Koa<Koa.DefaultState, Server.Context>();
  app.proxy = true;

  const { secret, oldSecrets, hmacAlgorithm } = server.config.security.cookies;
  app.keys = new KeyGrip(
    [secret.value, ...oldSecrets.map((s) => s.value)],
    hmacAlgorithm,
    "base64url",
  );

  // Incorrect types for easy-ws.
  // eslint-disable-next-line @typescript-eslint/ban-ts-comment
  // @ts-expect-error
  // eslint-disable-next-line @typescript-eslint/no-unsafe-argument
  app.use(EasyWS());
  app.use(async (ctx, next): Promise<void> => {
    ctx.server = server;
    await next();
  });
  app.use(Logging.middleware(server.logger));
  app.use(async (ctx, next): Promise<void> => {
    try {
      await next();
    } catch (error) {
      const { status, message } = Errors.handler(ctx.logger, error);
      if (status === StatusCodes.UNAUTHORIZED) {
        ctx.cookies.set(Auth.sessionCookieName, null, { signed: true });
      }
      ctx.status = status;
      ctx.body = message;
    }
  });

  const root = Server.router();

  const api = Routes.api(server.config);
  root.use("/api", api.routes(), api.allowedMethods());

  app.use(root.routes()).use(root.allowedMethods());

  const listening = app.listen(
    server.config.listenOn.port,
    server.config.listenOn.address,
    () => {
      server.logger.info(
        `Listening on ${server.config.listenOn.address}:${server.config.listenOn.port}.`,
      );
    },
  );

  // This is a workaround to stop websockets being killed. Not ideal but we
  // should always be behind a proxy anyway, so we'll offload the
  // responsibility there.
  listening.requestTimeout = 0;
  listening.headersTimeout = 0;

  process.on("SIGTERM", () => {
    unload(server)
      .then(() => {
        process.exit(ExitCodes.OK);
      })
      .catch((error: unknown) => {
        server.logger.error({ err: error }, "Error while shutting down");
        process.exit(ExitCodes.SHUTDOWN_ERROR);
      });
  });

  await server.ready;
  server.logger.info("Server loaded and fully ready.");
  await Background.runTasks(server);
};

async function main(): Promise<void> {
  const config = await Config.load();
  const logger = await init(config);
  logger.info(`Initialised, log level ${config.logging.level}.`);
  try {
    const server = await load(config, logger);
    await start(server);
  } catch (error) {
    logger.error({ err: error }, "Unhandled exception.");
    process.exit(ExitCodes.UNHANDLED_EXCEPTION);
  }
}

main().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : JSON.stringify(error);
  console.error(`Error while initializing: ${message}`);
  console.error(error);
  process.exit(ExitCodes.INITIALIZATION_ERROR);
});
