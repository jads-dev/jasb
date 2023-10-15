import { Feed } from "../../internal/feed.js";

export interface Notifier {
  notify(getEvent: () => Promise<Feed.Event>): Promise<void>;
}
