import type { Feed } from "../../internal/feed.js";
import type { Tasks } from "./tasks.js";

export const sendExternalNotification = (
  getEvent: () => Promise<Feed.Event>,
): Tasks.Task<Tasks.SingleRunResult> => ({
  name: "Send External Notification",
  details: {},
  execute: async (server) => {
    await server.externalNotifier.notify(getEvent);
    return { finished: true };
  },
});
