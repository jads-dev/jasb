import { default as BodyParser } from "body-parser";
import { default as CookieParser } from "cookie-parser";
import { default as Cors } from "cors";
import { default as Express } from "express";
import { default as FileUpload } from "express-fileupload";
import { default as Helmet } from "helmet";
import { default as SourceMapSupport } from "source-map-support";
import { default as Winston } from "winston";

import { ObjectUpload } from "./data/object-upload.js";
import { Store } from "./data/store.js";
import { Server } from "./server.js";
import { Auth } from "./server/auth.js";
import { Background } from "./server/background.js";
import { Config } from "./server/config.js";
import { Errors } from "./server/errors.js";
import { ExitCodes } from "./server/exit-codes.js";
import { Logger } from "./server/logger.js";
import { DiscordNotifier, NullNotifier } from "./server/notifier.js";
import { Routes } from "./server/routes.js";

SourceMapSupport.install();

const init = async (config: Config.Server): Promise<Winston.Logger> =>
  Logger.create(config.logLevel);

const load = async (
  config: Config.Server,
  logger: Winston.Logger,
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
  const app = Express();

  app.use(Helmet());
  app.set("trust proxy", true);
  app.use(BodyParser.json());
  app.use(BodyParser.raw());
  app.use(BodyParser.text());
  app.use(CookieParser());
  app.use(
    FileUpload({
      limits: { fileSize: 25 * 1024 * 1024, files: 1 },
      abortOnLimit: true,
    }),
  );

  const cors = Cors({
    origin: server.config.clientOrigin,
    credentials: true,
  });
  app.use(cors);
  app.options("*", cors);

  app.use(Routes.api(server));

  app.use(Errors.express(server.logger));

  await app.listen(server.config.listenOn.port, server.config.listenOn.address);
  server.logger.info(
    `Listening on ${server.config.listenOn.address}:${server.config.listenOn.port}.`,
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
