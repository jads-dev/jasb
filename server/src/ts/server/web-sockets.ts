import * as Joda from "@js-joda/core";
import * as Pool from "generic-pool";
import { StatusCodes } from "http-status-codes";
import { default as Listen, type Subscriber } from "pg-listen";
import type { WebSocket } from "ws";

import { Store } from "../data/store.js";
import { Notifications } from "../public/notifications.js";
import { Server } from "../server/model.js";
import { Promises } from "../util/promises.js";
import { Credentials } from "./auth/credentials.js";
import type { Config } from "./config.js";
import { WebError } from "./errors.js";
import type { Logging } from "./logging.js";

const wrapLogErrors =
  <TArgs extends [...unknown[]]>(
    logger: Logging.Logger,
    doAsync: (...args: TArgs) => Promise<void>,
  ): ((...args: TArgs) => void) =>
  (...args): void => {
    doAsync(...args).catch((error: unknown) => {
      logger.error({ err: error }, "Unhandled error in WebSocket handler.");
    });
  };

export class WebSockets {
  #pool: Pool.Pool<Subscriber>;

  constructor(config: Config.Server) {
    const factory: Pool.Factory<Subscriber> = {
      create: async () => {
        const subscriber =
          // Bad typing.
          // eslint-disable-next-line @typescript-eslint/ban-ts-comment
          // @ts-expect-error
          Listen({
            connectionString: Store.connectionString(config.store.source),
          }) as Subscriber;
        await subscriber.connect();
        return subscriber;
      },
      destroy: async (subscriber) => {
        await subscriber.close();
      },
      validate: (subscriber) =>
        Promise.resolve(subscriber.getSubscribedChannels().length === 0),
    };
    this.#pool = Pool.createPool(factory, {
      max: config.store.source.maxListenConnections,
      autostart: false,
    });
  }

  static async init(config: Config.Server): Promise<WebSockets> {
    const webSockets = new WebSockets(config);
    webSockets.#pool.start();
    await webSockets.#pool.ready();
    return webSockets;
  }

  async #getSubscriber(): Promise<Subscriber> {
    try {
      return await this.#pool.acquire();
    } catch (error) {
      throw new WebError(
        StatusCodes.SERVICE_UNAVAILABLE,
        "Too many clients connected, try again later.",
      );
    }
  }

  async attach(
    { store }: Server.State,
    logger: Logging.Logger,
    userId: number,
    credential: Credentials.Identifying,
    socket: WebSocket,
  ): Promise<void> {
    logger.debug(
      `WebSocket attached for ${Credentials.actingUser(credential)}.`,
    );
    const channel = `user_notifications_${userId}`;
    const keepAliveInterval = Joda.Duration.ofSeconds(30);
    let closed = false;
    let lastReceivedMessage = Joda.Instant.now();

    const subscriber = await this.#getSubscriber();

    subscriber.notifications.on(
      channel,
      wrapLogErrors(logger, async (notificationId: number): Promise<void> => {
        const notification = await store.getNotification(
          credential,
          notificationId as Notifications.Id,
        );
        socket.send(
          JSON.stringify(
            Notifications.Notification.encode(
              Notifications.fromInternal(notification),
            ),
          ),
        );
      }),
    );

    socket.on(
      "close",
      wrapLogErrors(logger, async () => {
        if (!closed) {
          logger.debug(
            `WebSocket closed for ${Credentials.actingUser(credential)}.`,
          );
          await subscriber.unlistenAll();
          closed = true;
          await this.#pool.release(subscriber);
        }
      }),
    );

    socket.on("pong", () => {
      lastReceivedMessage = Joda.Instant.now();
    });

    await subscriber.listenTo(channel);

    wrapLogErrors(logger, async () => {
      let failedCheck = false;
      while (!closed) {
        const startTime = Joda.Instant.now();
        await Promises.wait(keepAliveInterval);
        if (lastReceivedMessage.isBefore(startTime)) {
          if (failedCheck) {
            socket.close();
          } else {
            failedCheck = true;
            socket.ping();
          }
        } else {
          failedCheck = false;
        }
      }
    })();
  }
}
