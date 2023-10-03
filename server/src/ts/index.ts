import { default as Router } from "@koa/router";
import { StatusCodes } from "http-status-codes";
import { default as KeyGrip } from "keygrip";
import { default as Koa } from "koa";
import { default as EasyWS } from "koa-easy-ws";

import { ObjectUpload } from "./data/object-upload.js";
import { Store } from "./data/store.js";
import type { Server } from "./server.js";
import { Auth } from "./server/auth.js";
import { Background } from "./server/background.js";
import { Config } from "./server/config.js";
import { handler } from "./server/errors.js";
import { ExitCodes } from "./server/exit-codes.js";
import { DiscordNotifier, NullNotifier } from "./server/external-notifier.js";
import { Logging } from "./server/logging.js";
import { Routes } from "./server/routes.js";
import { WebSockets } from "./server/web-sockets.js";

const init = (config: Config.Server): Promise<Logging.Logger> =>
  Promise.resolve(Logging.init(config.logging));

const load = async (
  config: Config.Server,
  logger: Logging.Logger,
): Promise<Server.State> => {
  const notifier =
    config.notifier !== undefined
      ? await DiscordNotifier.create(logger, config, config.notifier)
      : new NullNotifier();
  const avatarCache = await ObjectUpload.init(config.avatarCache);
  const store = await Store.load(logger, config, notifier, avatarCache);
  return {
    config,
    logger,
    store,
    auth: await Auth.init(config.auth, store),
    webSockets: new WebSockets(),
    externalNotifier: notifier,
    imageUpload: await ObjectUpload.init(config.imageUpload),
    avatarCache,
  };
};

const unload = async (server: Server.State): Promise<void> => {
  await server.store.unload();
};

const start = async (server: Server.State): Promise<void> => {
  const app = new Koa();
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
  app.use(Logging.middleware(server.logger));
  app.use(async (ctx, next): Promise<void> => {
    try {
      await next();
    } catch (error) {
      const { status, message } = handler(server.logger, error);
      if (status === StatusCodes.UNAUTHORIZED) {
        ctx.cookies.set(Auth.sessionCookieName, null, { signed: true });
      }
      ctx.status = status;
      ctx.body = message;
    }
  });

  const root = new Router();

  const api = Routes.api(server);
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
        process.exit();
      })
      .catch((error) => {
        console.log(`Error while shutting down: ${error}`);
        process.exit(ExitCodes.SHUTDOWN_ERROR);
      });
  });

  await Background.runTasks(server);
};

async function main(): Promise<void> {
  const config = await Config.load();
  const logger = await init(config);
  try {
    const server = await load(config, logger);
    await start(server);
  } catch (error) {
    logger.error(`Unhandled exception: ${(error as Error).message}.`, {
      exception: error,
    });
    process.exit(ExitCodes.UNHANDLED_EXCEPTION);
  }
}

main().catch((error) => {
  console.log(`Error while initializing: ${error}`);
  process.exit(ExitCodes.INITIALIZATION_ERROR);
});
