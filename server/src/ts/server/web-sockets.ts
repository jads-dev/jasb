import { default as Listen, type Subscriber } from "pg-listen";
import type { WebSocket } from "ws";

import { Store } from "../data/store.js";
import { Notifications } from "../public/notifications.js";
import { Server } from "../server/model.js";
import type { Logging } from "./logging.js";
import type { SessionCookie } from "./routes/auth.js";

const wrapLogErrors = (
  logger: Logging.Logger,
  async: () => Promise<void>,
): void => {
  async().catch((error) => {
    logger.error(error);
  });
};

export class WebSockets {
  async attach(
    { logger, store }: Server.State,
    userId: number,
    session: SessionCookie,
    socket: WebSocket,
  ): Promise<void> {
    const channel = `user_notifications_${userId}`;

    // Bad typing.
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-expect-error
    const subscriber = Listen({
      connectionString: Store.connectionString(store.config.store.source),
    }) as Subscriber;

    subscriber.notifications.on(channel, (notificationId: number) => {
      wrapLogErrors(logger, async (): Promise<void> => {
        const notification = await store.getNotification(
          session.user,
          session.session,
          notificationId as Notifications.Id,
        );
        socket.send(
          JSON.stringify(
            Notifications.Notification.encode(
              Notifications.fromInternal(notification),
            ),
          ),
        );
      });
    });

    socket.on("close", () => {
      wrapLogErrors(logger, async () => {
        await subscriber.close();
      });
    });

    await subscriber.connect();
    await subscriber.listenTo(channel);
  }
}
