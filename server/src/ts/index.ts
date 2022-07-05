import { default as Cors } from "@koa/cors";
import { default as Router } from "@koa/router";
import { default as Koa } from "koa";
import { default as Helmet } from "koa-helmet";
import { default as SourceMapSupport } from "source-map-support";

import { ObjectUpload } from "./data/object-upload.js";
import { Store } from "./data/store.js";
import { Server } from "./server.js";
import { Auth } from "./server/auth.js";
import { Background } from "./server/background.js";
import { Config } from "./server/config.js";
import { Errors } from "./server/errors.js";
import { ExitCodes } from "./server/exit-codes.js";
import { Logging } from "./server/logging.js";
import { DiscordNotifier, NullNotifier } from "./server/notifier.js";
import { Routes } from "./server/routes.js";

SourceMapSupport.install();

const init = async (config: Config.Server): Promise<Logging.Logger> =>
  Logging.init(config.logging);

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
    notifier,
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

  app.use(Helmet());

  const cors = Cors({
    origin: server.config.clientOrigin,
    credentials: true,
  });
  app.use(cors);

  app.use(Logging.middleware(server.logger));

  const root = new Router();

  const api = Routes.api(server);
  root.use("/api", api.routes(), api.allowedMethods());

  app.use(root.routes()).use(root.allowedMethods());

  app.use(Errors.middleware(server.logger));

  await app.listen(
    server.config.listenOn.port,
    server.config.listenOn.address,
    async () => {
      server.logger.info(
        `Listening on ${server.config.listenOn.address}:${server.config.listenOn.port}.`,
      );
    },
  );

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
