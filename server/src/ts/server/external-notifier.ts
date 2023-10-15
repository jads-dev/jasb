import { Expect } from "../util/expect.js";
import type { Config } from "./config.js";
import { DiscordNotifier } from "./external-notifier/discord.js";
import type { Notifier } from "./external-notifier/notifiers.js";
import { NullNotifier } from "./external-notifier/null.js";
import { Logging } from "./logging.js";

export const fromConfig = async (
  logger: Logging.Logger,
  config: Config.Server,
): Promise<Notifier> => {
  try {
    const notifierConfig = config.notifier;
    if (notifierConfig === undefined) {
      logger.info(
        "Configured with null notifier, external notifications disabled.",
      );
      return new NullNotifier();
    } else {
      switch (notifierConfig.service) {
        case "Discord":
          logger.info("Configured with discord notifier.");
          return await DiscordNotifier.create(config, notifierConfig);
        default:
          return Expect.exhaustive("External notifier service.")(
            notifierConfig.service,
          );
      }
    }
  } catch (error: unknown) {
    logger.error(
      { err: error },
      "Failure while setting up notifier, reverting to null notifier.",
    );
    return new NullNotifier();
  }
};

export type { Notifier } from "./external-notifier/notifiers.js";
export * as ExternalNotifier from "./external-notifier.js";
