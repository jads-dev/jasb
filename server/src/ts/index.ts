import { default as BodyParser } from "body-parser";
import { default as CookieParser } from "cookie-parser";
import { default as Cors } from "cors";
import { default as Express } from "express";
import { default as Helmet } from "helmet";
import { default as SourceMapSupport } from "source-map-support";
import { default as Winston } from "winston";

import { Server } from "./server";
import { Auth } from "./server/auth";
import { Config } from "./server/config";
import { Errors } from "./server/errors";
import { ExitCodes } from "./server/exit-codes";
import { Logger } from "./server/logger";
import { Routes } from "./server/routes";
import { Store } from "./server/store";

SourceMapSupport.install();

const init = async (config: Config.Server): Promise<Winston.Logger> =>
  Logger.create(config.logLevel);

const load = async (
  config: Config.Server,
  logger: Winston.Logger
): Promise<Server.State> => {
  const store = await Store.load(logger, config);
  return {
    config,
    logger,
    store,
    auth: await Auth.init(config.auth, store),
  };
};

const start = async (server: Server.State): Promise<void> => {
  const app = Express();

  app.use(Helmet());
  app.set("trust proxy", true);
  app.use(BodyParser.json());
  app.use(BodyParser.raw());
  app.use(BodyParser.text());
  app.use(CookieParser());

  const cors = Cors({
    origin: server.config.clientOrigin,
    credentials: true,
  });
  app.use(cors);
  app.options("*", cors);

  app.use(Logger.express(server.logger));

  app.use(Routes.api(server));

  app.use(Errors.express(server.logger));

  app.listen(server.config.listenOn, async () => {
    server.logger.info(`Listening on ${server.config.listenOn}.`);
  });
};

async function main(): Promise<void> {
  const config = Config.builtIn;
  const logger = await init(config);
  try {
    const server = await load(config, logger);
    await start(server);
  } catch (error) {
    logger.error(`Unhandled exception: ${error.message}.`, {
      exception: error,
    });
    process.exit(ExitCodes.UNHANDLED_EXCEPTION);
  }
}

main().catch((error) => {
  console.log(`Error while initializing: ${error}`);
  process.exit(ExitCodes.INITIALIZATION_ERROR);
});
