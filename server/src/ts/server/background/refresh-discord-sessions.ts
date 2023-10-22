import type { Users } from "../../internal/users.js";
import { Promises } from "../../util/promises.js";
import type { DiscordToken } from "../auth.js";
import type { Logging } from "../logging.js";
import type { Server } from "../model.js";
import type { Tasks } from "./tasks.js";

interface Refresh {
  id: number;
  newToken: DiscordToken | undefined;
}

type Refreshed = Refresh & {
  newToken: Exclude<Refresh["newToken"], undefined>;
};

// We don't do this in parallel intentionally, so we don't smash the
// Discord API too hard.
async function* refreshSequentially(
  logger: Logging.Logger,
  server: Server.State,
  tokens: Iterable<Users.DiscordRefreshToken>,
): AsyncIterable<Refresh> {
  for (const { id, refresh_token } of tokens) {
    yield {
      id,
      newToken: await server.auth.refresh(logger, refresh_token),
    };
  }
}

export const refreshDiscordTokens = (server: Server.State): Tasks.Task => {
  const config = server.config.auth.discord.refresh;
  return {
    name: "Refresh Discord Tokens",
    details: {
      ...config,
    },
    execute: async (
      server: Server.State,
      logger: Logging.Logger,
    ): Promise<Tasks.Result> => {
      await Promises.wait(config.frequency);
      const toRefresh = await server.store.findSessionsToRefresh(
        config.frequency,
        config.expiryBuffer,
      );

      const refreshed: Refreshed[] = [];
      const expired: number[] = [];
      for await (const { id, newToken } of refreshSequentially(
        logger,
        server,
        toRefresh,
      )) {
        if (newToken !== undefined) {
          refreshed.push({
            id,
            newToken,
          });
        } else {
          expired.push(id);
        }
      }

      const refreshedCount =
        await server.store.updateRefreshedSessions(refreshed);

      const expiredCount = await server.store.deleteExpiredSessions(expired);

      if (refreshedCount > 0 || expiredCount > 0) {
        if (refreshedCount > 0) {
          logger.info(`Refreshed ${refreshedCount} expiring discord tokens.`);
        }
        if (expiredCount > 0) {
          logger.warn(
            `Deleted ${expiredCount} expired discord tokens and affiliated sessions.`,
          );
        }
      } else {
        logger.debug("No expiring discord tokens found.");
      }

      return { finished: false };
    },
  };
};
