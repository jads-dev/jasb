import { Feed } from "../../internal/feed.js";
import type { Notifier } from "./notifiers.js";

export class NullNotifier implements Notifier {
  async notify(_getEvent: () => Promise<Feed.Event>): Promise<void> {
    // Do Nothing.
  }
}
